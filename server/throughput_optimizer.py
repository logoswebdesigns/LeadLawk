#!/usr/bin/env python3
"""
Throughput Optimizer for LeadLawk
Maximizes lead collection throughput while maintaining reliability
Based on LinkedIn's Kafka throughput patterns and Google's load balancing strategies
"""

import asyncio
import time
from typing import Dict, List, Optional, Any
from dataclasses import dataclass, field
from datetime import datetime, timedelta
import statistics
from collections import deque
import logging
import threading
from concurrent.futures import ThreadPoolExecutor, as_completed

logger = logging.getLogger(__name__)

@dataclass
class ThroughputMetrics:
    """Real-time throughput metrics"""
    leads_per_minute: float = 0.0
    leads_per_hour: float = 0.0
    average_processing_time: float = 0.0
    success_rate: float = 0.0
    queue_depth: int = 0
    active_workers: int = 0
    cpu_utilization: float = 0.0
    memory_utilization: float = 0.0
    
class AdaptiveRateLimiter:
    """
    Adaptive rate limiting based on system performance
    Inspired by Netflix's adaptive concurrency limits
    """
    
    def __init__(self, 
                 initial_rate: float = 10.0,  # requests per second
                 min_rate: float = 1.0,
                 max_rate: float = 100.0):
        self.current_rate = initial_rate
        self.min_rate = min_rate
        self.max_rate = max_rate
        self.success_history = deque(maxlen=100)
        self.latency_history = deque(maxlen=100)
        self.last_adjustment = time.time()
        self._lock = threading.Lock()
    
    def should_proceed(self) -> bool:
        """Check if request should proceed based on current rate"""
        with self._lock:
            now = time.time()
            interval = 1.0 / self.current_rate
            
            if not hasattr(self, 'last_request'):
                self.last_request = now
                return True
            
            elapsed = now - self.last_request
            if elapsed >= interval:
                self.last_request = now
                return True
            
            return False
    
    def record_result(self, success: bool, latency: float):
        """Record result and adjust rate accordingly"""
        with self._lock:
            self.success_history.append(success)
            self.latency_history.append(latency)
            
            # Adjust rate every 10 seconds
            if time.time() - self.last_adjustment > 10:
                self._adjust_rate()
                self.last_adjustment = time.time()
    
    def _adjust_rate(self):
        """Adjust rate based on performance metrics"""
        if len(self.success_history) < 10:
            return
        
        success_rate = sum(self.success_history) / len(self.success_history)
        avg_latency = statistics.mean(self.latency_history)
        
        # Increase rate if performance is good
        if success_rate > 0.95 and avg_latency < 2.0:
            self.current_rate = min(self.current_rate * 1.2, self.max_rate)
            logger.info(f"Increasing rate to {self.current_rate:.2f} req/s")
        
        # Decrease rate if performance is poor
        elif success_rate < 0.8 or avg_latency > 5.0:
            self.current_rate = max(self.current_rate * 0.8, self.min_rate)
            logger.warning(f"Decreasing rate to {self.current_rate:.2f} req/s")

class ParallelExecutor:
    """
    Parallel execution engine for maximum throughput
    Based on Google's MapReduce and Apache Spark patterns
    """
    
    def __init__(self, max_workers: int = 10):
        self.max_workers = max_workers
        self.executor = ThreadPoolExecutor(max_workers=max_workers)
        self.active_tasks = set()
        self.completed_tasks = deque(maxlen=1000)
        self.metrics = ThroughputMetrics()
        self._lock = threading.Lock()
        self._start_time = time.time()
        self._task_times = deque(maxlen=100)
    
    def submit_batch(self, tasks: List[Dict[str, Any]]) -> List[Any]:
        """Submit batch of tasks for parallel execution"""
        futures = []
        
        for task in tasks:
            future = self.executor.submit(self._execute_task, task)
            futures.append(future)
            with self._lock:
                self.active_tasks.add(future)
        
        results = []
        for future in as_completed(futures):
            try:
                result = future.result(timeout=30)
                results.append(result)
                with self._lock:
                    self.active_tasks.discard(future)
                    self.completed_tasks.append({
                        'timestamp': datetime.now(),
                        'result': result
                    })
            except Exception as e:
                logger.error(f"Task failed: {e}")
                with self._lock:
                    self.active_tasks.discard(future)
        
        self._update_metrics()
        return results
    
    def _execute_task(self, task: Dict[str, Any]) -> Any:
        """Execute individual task with timing"""
        start_time = time.time()
        
        try:
            # Execute the actual task
            from browser_automation import BrowserAutomation
            automation = BrowserAutomation()
            result = automation.process_single_lead(task)
            
            execution_time = time.time() - start_time
            with self._lock:
                self._task_times.append(execution_time)
            
            return result
            
        except Exception as e:
            logger.error(f"Task execution failed: {e}")
            raise
    
    def _update_metrics(self):
        """Update throughput metrics"""
        now = time.time()
        elapsed = now - self._start_time
        
        # Calculate throughput
        completed_count = len(self.completed_tasks)
        self.metrics.leads_per_minute = (completed_count / elapsed) * 60
        self.metrics.leads_per_hour = self.metrics.leads_per_minute * 60
        
        # Calculate average processing time
        if self._task_times:
            self.metrics.average_processing_time = statistics.mean(self._task_times)
        
        # Calculate success rate
        if self.completed_tasks:
            successful = sum(1 for t in self.completed_tasks if t.get('result'))
            self.metrics.success_rate = successful / len(self.completed_tasks)
        
        # Update worker and queue metrics
        self.metrics.active_workers = len(self.active_tasks)
        self.metrics.queue_depth = self.executor._work_queue.qsize()
        
        # Get system metrics
        import psutil
        self.metrics.cpu_utilization = psutil.cpu_percent()
        self.metrics.memory_utilization = psutil.virtual_memory().percent

class LoadBalancer:
    """
    Dynamic load balancing across multiple workers
    Based on HAProxy and NGINX load balancing algorithms
    """
    
    def __init__(self, worker_count: int = 3):
        self.workers = []
        self.worker_loads = {}
        self.worker_performance = {}
        
        # Initialize workers
        for i in range(worker_count):
            worker = ParallelExecutor(max_workers=5)
            self.workers.append(worker)
            self.worker_loads[i] = 0
            self.worker_performance[i] = deque(maxlen=50)
    
    def distribute_load(self, tasks: List[Dict[str, Any]]) -> List[Any]:
        """Distribute tasks across workers using weighted round-robin"""
        
        # Calculate worker weights based on performance
        weights = self._calculate_weights()
        
        # Distribute tasks
        task_distribution = [[] for _ in self.workers]
        
        for i, task in enumerate(tasks):
            # Select worker based on weighted distribution
            worker_index = self._select_worker(weights)
            task_distribution[worker_index].append(task)
            self.worker_loads[worker_index] += 1
        
        # Execute tasks in parallel across workers
        results = []
        futures = []
        
        with ThreadPoolExecutor(max_workers=len(self.workers)) as executor:
            for i, worker in enumerate(self.workers):
                if task_distribution[i]:
                    future = executor.submit(
                        worker.submit_batch, 
                        task_distribution[i]
                    )
                    futures.append((i, future))
            
            for worker_index, future in futures:
                try:
                    worker_results = future.result(timeout=300)
                    results.extend(worker_results)
                    
                    # Update performance metrics
                    worker = self.workers[worker_index]
                    self.worker_performance[worker_index].append({
                        'throughput': worker.metrics.leads_per_minute,
                        'success_rate': worker.metrics.success_rate,
                        'latency': worker.metrics.average_processing_time
                    })
                    
                except Exception as e:
                    logger.error(f"Worker {worker_index} failed: {e}")
        
        return results
    
    def _calculate_weights(self) -> List[float]:
        """Calculate worker weights based on performance"""
        weights = []
        
        for i in range(len(self.workers)):
            if not self.worker_performance[i]:
                weights.append(1.0)  # Default weight for new workers
            else:
                # Calculate weight based on recent performance
                perf = self.worker_performance[i]
                avg_throughput = statistics.mean(p['throughput'] for p in perf)
                avg_success = statistics.mean(p['success_rate'] for p in perf)
                avg_latency = statistics.mean(p['latency'] for p in perf)
                
                # Combined score (higher is better)
                score = (avg_throughput * avg_success) / (avg_latency + 1)
                weights.append(max(score, 0.1))  # Minimum weight of 0.1
        
        # Normalize weights
        total = sum(weights)
        return [w / total for w in weights]
    
    def _select_worker(self, weights: List[float]) -> int:
        """Select worker using weighted random selection"""
        import random
        return random.choices(range(len(self.workers)), weights=weights)[0]

class ThroughputOptimizer:
    """
    Main throughput optimization orchestrator
    Combines all optimization strategies
    """
    
    def __init__(self):
        self.rate_limiter = AdaptiveRateLimiter()
        self.load_balancer = LoadBalancer(worker_count=3)
        self.metrics_history = deque(maxlen=1000)
        self.optimization_thread = None
        self.running = False
    
    def start(self):
        """Start throughput optimization"""
        self.running = True
        self.optimization_thread = threading.Thread(target=self._optimization_loop)
        self.optimization_thread.start()
        logger.info("Throughput optimizer started")
    
    def stop(self):
        """Stop throughput optimization"""
        self.running = False
        if self.optimization_thread:
            self.optimization_thread.join()
        logger.info("Throughput optimizer stopped")
    
    def _optimization_loop(self):
        """Main optimization loop"""
        while self.running:
            try:
                # Collect metrics
                metrics = self._collect_metrics()
                self.metrics_history.append({
                    'timestamp': datetime.now(),
                    'metrics': metrics
                })
                
                # Apply optimizations
                self._apply_optimizations(metrics)
                
                # Log performance
                logger.info(f"Throughput: {metrics['leads_per_hour']:.1f} leads/hour, "
                          f"Success rate: {metrics['success_rate']:.2%}")
                
                time.sleep(10)  # Check every 10 seconds
                
            except Exception as e:
                logger.error(f"Optimization loop error: {e}")
    
    def _collect_metrics(self) -> Dict[str, Any]:
        """Collect current performance metrics"""
        total_metrics = {
            'leads_per_hour': 0,
            'success_rate': 0,
            'avg_latency': 0,
            'queue_depth': 0,
            'cpu_usage': 0,
            'memory_usage': 0
        }
        
        # Aggregate metrics from all workers
        for worker in self.load_balancer.workers:
            metrics = worker.metrics
            total_metrics['leads_per_hour'] += metrics.leads_per_hour
            total_metrics['success_rate'] += metrics.success_rate
            total_metrics['avg_latency'] += metrics.average_processing_time
            total_metrics['queue_depth'] += metrics.queue_depth
        
        # Average the rates
        worker_count = len(self.load_balancer.workers)
        total_metrics['success_rate'] /= worker_count
        total_metrics['avg_latency'] /= worker_count
        
        # Get system metrics
        import psutil
        total_metrics['cpu_usage'] = psutil.cpu_percent()
        total_metrics['memory_usage'] = psutil.virtual_memory().percent
        
        return total_metrics
    
    def _apply_optimizations(self, metrics: Dict[str, Any]):
        """Apply optimizations based on metrics"""
        
        # Scale workers if needed
        if metrics['queue_depth'] > 100 and metrics['cpu_usage'] < 70:
            logger.info("High queue depth - considering scaling workers")
            # Could add more workers here
        
        # Adjust rate limiting
        if metrics['success_rate'] < 0.8:
            logger.warning("Low success rate - reducing load")
            # Rate limiter will auto-adjust
        
        # Memory management
        if metrics['memory_usage'] > 80:
            logger.warning("High memory usage - triggering cleanup")
            import gc
            gc.collect()
    
    def get_dashboard_data(self) -> Dict[str, Any]:
        """Get dashboard data for monitoring"""
        current_metrics = self._collect_metrics()
        
        # Calculate trends
        recent_metrics = list(self.metrics_history)[-100:]
        if recent_metrics:
            hourly_trend = self._calculate_trend(
                [m['metrics']['leads_per_hour'] for m in recent_metrics]
            )
        else:
            hourly_trend = 0
        
        return {
            'current': current_metrics,
            'trend': hourly_trend,
            'history': recent_metrics,
            'workers': len(self.load_balancer.workers),
            'uptime': time.time() - self.load_balancer.workers[0]._start_time
        }
    
    def _calculate_trend(self, values: List[float]) -> float:
        """Calculate trend (positive or negative)"""
        if len(values) < 2:
            return 0
        
        # Simple linear regression
        n = len(values)
        x = list(range(n))
        
        x_mean = sum(x) / n
        y_mean = sum(values) / n
        
        numerator = sum((x[i] - x_mean) * (values[i] - y_mean) for i in range(n))
        denominator = sum((x[i] - x_mean) ** 2 for i in range(n))
        
        if denominator == 0:
            return 0
        
        return numerator / denominator

# Global throughput optimizer instance
throughput_optimizer = ThroughputOptimizer()