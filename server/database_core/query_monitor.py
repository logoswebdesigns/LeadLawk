"""
Query performance monitoring for database optimization.
Pattern: Observer Pattern - monitors query execution.
Single Responsibility: Query performance tracking.
"""

from sqlalchemy import event
from sqlalchemy.engine import Engine
from datetime import datetime
from typing import Dict, List, Optional
import logging
import time
from collections import defaultdict
import json

logger = logging.getLogger(__name__)

class QueryMonitor:
    """Monitors and analyzes database query performance."""
    
    def __init__(self, slow_query_threshold: float = 0.5):
        """Initialize query monitor with slow query threshold in seconds."""
        self.slow_query_threshold = slow_query_threshold
        self.query_stats = defaultdict(lambda: {
            'count': 0,
            'total_time': 0,
            'min_time': float('inf'),
            'max_time': 0,
            'avg_time': 0,
            'slow_count': 0
        })
        self.slow_queries = []
        self.active_queries = {}
        self._enabled = False
    
    def enable(self, engine: Engine) -> None:
        """Enable query monitoring for the given engine."""
        if self._enabled:
            return
        
        @event.listens_for(engine, "before_cursor_execute")
        def before_cursor_execute(conn, cursor, statement, parameters, context, executemany):
            self._start_query(conn, statement)
        
        @event.listens_for(engine, "after_cursor_execute")
        def after_cursor_execute(conn, cursor, statement, parameters, context, executemany):
            self._end_query(conn, statement, parameters)
        
        self._enabled = True
        logger.info("Query monitoring enabled")
    
    def _start_query(self, conn, statement: str) -> None:
        """Record query start time."""
        self.active_queries[id(conn)] = {
            'statement': statement,
            'start_time': time.time()
        }
    
    def _end_query(self, conn, statement: str, parameters) -> None:
        """Record query end time and update statistics."""
        query_id = id(conn)
        if query_id not in self.active_queries:
            return
        
        query_info = self.active_queries.pop(query_id)
        execution_time = time.time() - query_info['start_time']
        
        # Normalize query for statistics
        normalized_query = self._normalize_query(statement)
        
        # Update statistics
        stats = self.query_stats[normalized_query]
        stats['count'] += 1
        stats['total_time'] += execution_time
        stats['min_time'] = min(stats['min_time'], execution_time)
        stats['max_time'] = max(stats['max_time'], execution_time)
        stats['avg_time'] = stats['total_time'] / stats['count']
        
        # Track slow queries
        if execution_time > self.slow_query_threshold:
            stats['slow_count'] += 1
            self.slow_queries.append({
                'query': statement,
                'normalized': normalized_query,
                'parameters': str(parameters) if parameters else None,
                'execution_time': execution_time,
                'timestamp': datetime.utcnow().isoformat()
            })
            
            # Keep only last 100 slow queries
            if len(self.slow_queries) > 100:
                self.slow_queries = self.slow_queries[-100:]
            
            logger.warning(f"Slow query detected ({execution_time:.3f}s): "
                         f"{statement[:100]}...")
    
    def _normalize_query(self, query: str) -> str:
        """Normalize query for grouping similar queries."""
        # Remove extra whitespace
        query = ' '.join(query.split())
        
        # Remove specific values (basic normalization)
        import re
        # Replace numbers with ?
        query = re.sub(r'\b\d+\b', '?', query)
        # Replace quoted strings with ?
        query = re.sub(r"'[^']*'", '?', query)
        
        # Truncate for storage
        return query[:200]
    
    def get_statistics(self) -> Dict:
        """Get query performance statistics."""
        return {
            'total_queries': sum(s['count'] for s in self.query_stats.values()),
            'unique_queries': len(self.query_stats),
            'slow_queries': len(self.slow_queries),
            'top_queries': self._get_top_queries(),
            'slowest_queries': self._get_slowest_queries()
        }
    
    def _get_top_queries(self, limit: int = 10) -> List[Dict]:
        """Get most frequently executed queries."""
        sorted_queries = sorted(
            self.query_stats.items(),
            key=lambda x: x[1]['count'],
            reverse=True
        )[:limit]
        
        return [
            {
                'query': query[:100],
                'count': stats['count'],
                'avg_time': stats['avg_time'],
                'total_time': stats['total_time']
            }
            for query, stats in sorted_queries
        ]
    
    def _get_slowest_queries(self, limit: int = 10) -> List[Dict]:
        """Get slowest queries by average execution time."""
        sorted_queries = sorted(
            self.query_stats.items(),
            key=lambda x: x[1]['avg_time'],
            reverse=True
        )[:limit]
        
        return [
            {
                'query': query[:100],
                'avg_time': stats['avg_time'],
                'max_time': stats['max_time'],
                'count': stats['count'],
                'slow_count': stats['slow_count']
            }
            for query, stats in sorted_queries
        ]
    
    def export_report(self, filepath: str) -> None:
        """Export performance report to JSON file."""
        report = {
            'generated_at': datetime.utcnow().isoformat(),
            'statistics': self.get_statistics(),
            'slow_queries': self.slow_queries[-50:],  # Last 50 slow queries
            'recommendations': self._get_recommendations()
        }
        
        with open(filepath, 'w') as f:
            json.dump(report, f, indent=2)
        
        logger.info(f"Query performance report exported to {filepath}")
    
    def _get_recommendations(self) -> List[str]:
        """Generate performance recommendations based on statistics."""
        recommendations = []
        
        # Check for N+1 query patterns
        for query, stats in self.query_stats.items():
            if stats['count'] > 100 and 'SELECT' in query.upper():
                if any(word in query.upper() for word in ['WHERE', 'JOIN']):
                    recommendations.append(
                        f"High frequency query detected ({stats['count']} times): "
                        f"Consider batch loading or eager loading"
                    )
        
        # Check for missing indices
        for slow_query in self.slow_queries[-10:]:
            if 'WHERE' in slow_query['query'].upper():
                recommendations.append(
                    f"Slow query with WHERE clause: Consider adding index"
                )
        
        return list(set(recommendations))[:10]  # Return top 10 unique recommendations

# Global query monitor instance
_query_monitor = None

def get_query_monitor() -> QueryMonitor:
    """Get or create the global query monitor."""
    global _query_monitor
    if _query_monitor is None:
        _query_monitor = QueryMonitor()
    return _query_monitor