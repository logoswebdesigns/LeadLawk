"""
Optimized lead service using query builder and unit of work patterns.
Pattern: Service Layer with Unit of Work and Query Builder.
Single Responsibility: Lead business logic with optimized queries.
"""

from typing import List, Optional, Dict, Any
from datetime import datetime, timedelta
from sqlalchemy.orm import Session

from database.unit_of_work import TransactionalService, UnitOfWork
from database.query_builder import LeadQueryBuilder
from models import Lead, LeadStatus, LeadTimelineEntry, TimelineEntryType

class OptimizedLeadService(TransactionalService):
    """Lead service with query optimization and transaction management."""
    
    def get_leads_with_relationships(
        self,
        user_id: str,
        status: Optional[LeadStatus] = None,
        page: int = 1,
        per_page: int = 20
    ) -> Dict[str, Any]:
        """Get leads with all relationships eager loaded (prevents N+1)."""
        with self.unit_of_work() as uow:
            builder = LeadQueryBuilder(uow.session, Lead)
            
            # Eager load all relationships to prevent N+1 queries
            builder.with_all_relationships()
            
            # Apply filters
            builder.filter_by(user_id=user_id)
            if status:
                builder.filter_by(status=status)
            
            # Apply ordering and pagination
            builder.order_by(Lead.created_at, 'desc')
            builder.paginate(page, per_page)
            
            # Get results
            leads = builder.all()
            total = builder.count()
            
            return {
                'leads': leads,
                'total': total,
                'page': page,
                'per_page': per_page,
                'pages': (total + per_page - 1) // per_page
            }
    
    def get_high_priority_leads(self, user_id: str) -> List[Lead]:
        """Get high priority leads based on conversion score and follow-up."""
        with self.unit_of_work() as uow:
            builder = LeadQueryBuilder(uow.session, Lead)
            
            # Eager load relationships
            builder.with_timeline().with_call_logs()
            
            # Get active leads with high conversion score
            high_score_leads = (
                builder
                .filter_by(user_id=user_id)
                .active_leads()
                .by_conversion_score(min_score=0.7)
                .limit(10)
                .all()
            )
            
            # Get leads needing follow-up
            builder = LeadQueryBuilder(uow.session, Lead)
            follow_up_leads = (
                builder
                .filter_by(user_id=user_id)
                .active_leads()
                .needs_follow_up()
                .order_by(Lead.follow_up_date, 'asc')
                .limit(10)
                .all()
            )
            
            # Combine and deduplicate
            lead_ids = set()
            priority_leads = []
            
            for lead in high_score_leads + follow_up_leads:
                if lead.id not in lead_ids:
                    lead_ids.add(lead.id)
                    priority_leads.append(lead)
            
            return priority_leads[:15]  # Return top 15
    
    def bulk_update_status(
        self,
        lead_ids: List[str],
        new_status: LeadStatus,
        user_id: str,
        notes: Optional[str] = None
    ) -> Dict[str, Any]:
        """Bulk update lead status within a single transaction."""
        updated = 0
        errors = []
        
        def update_lead(uow: UnitOfWork, lead_id: str):
            """Update single lead within transaction."""
            lead = uow.session.query(Lead).filter_by(
                id=lead_id,
                user_id=user_id
            ).first()
            
            if not lead:
                errors.append(f"Lead {lead_id} not found")
                return
            
            old_status = lead.status
            lead.status = new_status
            lead.updated_at = datetime.utcnow()
            
            # Add timeline entry
            timeline_entry = LeadTimelineEntry(
                id=f"tle_{datetime.utcnow().timestamp()}",
                lead_id=lead.id,
                created_by_id=user_id,
                type=TimelineEntryType.STATUS_CHANGE,
                title=f"Status changed to {new_status.value}",
                description=notes,
                previous_status=old_status,
                new_status=new_status,
                created_at=datetime.utcnow()
            )
            
            uow.add(timeline_entry)
            nonlocal updated
            updated += 1
        
        # Process all updates in a single transaction
        with self.unit_of_work() as uow:
            for lead_id in lead_ids:
                update_lead(uow, lead_id)
        
        return {
            'updated': updated,
            'errors': errors,
            'success': len(errors) == 0
        }
    
    def get_conversion_analytics(self, user_id: str) -> Dict[str, Any]:
        """Get conversion analytics with optimized queries."""
        with self.unit_of_work() as uow:
            # Use raw SQL for complex aggregations (more efficient)
            query = """
            SELECT 
                status,
                COUNT(*) as count,
                AVG(conversion_score) as avg_score,
                MAX(conversion_score) as max_score,
                MIN(conversion_score) as min_score
            FROM leads
            WHERE user_id = :user_id
            GROUP BY status
            """
            
            result = uow.session.execute(
                query,
                {'user_id': user_id}
            ).fetchall()
            
            status_stats = {
                row[0]: {
                    'count': row[1],
                    'avg_score': row[2],
                    'max_score': row[3],
                    'min_score': row[4]
                }
                for row in result
            }
            
            # Get time-based conversion metrics
            time_query = """
            SELECT 
                DATE(created_at) as date,
                COUNT(*) as total,
                SUM(CASE WHEN status = 'converted' THEN 1 ELSE 0 END) as converted
            FROM leads
            WHERE user_id = :user_id
                AND created_at > datetime('now', '-30 days')
            GROUP BY DATE(created_at)
            ORDER BY date DESC
            """
            
            time_result = uow.session.execute(
                time_query,
                {'user_id': user_id}
            ).fetchall()
            
            daily_stats = [
                {
                    'date': row[0],
                    'total': row[1],
                    'converted': row[2],
                    'conversion_rate': row[2] / row[1] if row[1] > 0 else 0
                }
                for row in time_result
            ]
            
            return {
                'status_breakdown': status_stats,
                'daily_stats': daily_stats,
                'total_leads': sum(s['count'] for s in status_stats.values()),
                'conversion_rate': (
                    status_stats.get('converted', {}).get('count', 0) /
                    sum(s['count'] for s in status_stats.values())
                    if status_stats else 0
                )
            }
    
    def search_leads_optimized(
        self,
        user_id: str,
        search_term: str,
        filters: Dict[str, Any]
    ) -> List[Lead]:
        """Search leads with optimized full-text search."""
        with self.unit_of_work() as uow:
            builder = LeadQueryBuilder(uow.session, Lead)
            
            # Eager load for performance
            builder.with_timeline()
            
            # Base filter
            builder.filter_by(user_id=user_id)
            
            # Apply search (use LIKE for SQLite, would use FTS for PostgreSQL)
            if search_term:
                search_pattern = f"%{search_term}%"
                builder.filter(
                    Lead.business_name.ilike(search_pattern) |
                    Lead.phone.like(search_pattern) |
                    Lead.location.ilike(search_pattern) |
                    Lead.notes.ilike(search_pattern)
                )
            
            # Apply additional filters
            if filters.get('status'):
                builder.filter_by(status=filters['status'])
            
            if filters.get('min_score'):
                builder.filter(Lead.conversion_score >= filters['min_score'])
            
            if filters.get('has_website') is not None:
                builder.filter_by(has_website=filters['has_website'])
            
            if filters.get('location'):
                builder.filter(Lead.location.ilike(f"%{filters['location']}%"))
            
            if filters.get('industry'):
                builder.filter_by(industry=filters['industry'])
            
            # Order by relevance (conversion score) and recency
            builder.order_by(Lead.conversion_score, 'desc')
            builder.order_by(Lead.created_at, 'desc')
            
            return builder.limit(50).all()