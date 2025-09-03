#!/usr/bin/env python3
"""
Resilience Manager for LeadLawk
Implements circuit breaker, retry, and bulkhead patterns
Based on Netflix Hystrix and AWS best practices
"""

import asyncio
import time
import logging
from typing import Any, Callable, Optional, TypeVar, Union
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from enum import Enum
import random
from functools import wraps
import threading
from collections import deque

logger = logging.getLogger(__name__)

T = TypeVar('T')

class CircuitState(Enum):
    """Circuit breaker states as per Martin Fowler's pattern"""
    CLOSED = "closed"  # Normal operation
    OPEN = "open"      # Failing, reject requests
    HALF_OPEN = "half_open"  # Testing recovery

@dataclass
class CircuitBreakerConfig:
    """Configuration for circuit breaker pattern"""
    failure_threshold: int = 5
    recovery_timeout: int = 60  # seconds
    expected_exception: type = Exception
    success_threshold: int = 2  # successes needed to close from half-open

class CircuitBreaker:
    """
    Circuit Breaker implementation based on Netflix Hystrix
    Prevents cascading failures in distributed systems
    """
    
    def __init__(self, name: str, config: CircuitBreakerConfig):
        self.name = name
        self.config = config
        self.state = CircuitState.CLOSED
        self.failure_count = 0
        self.success_count = 0
        self.last_failure_time: Optional[datetime] = None
        self._lock = threading.Lock()
        self.metrics = {
            "total_calls": 0,
            "successful_calls": 0,
            "failed_calls": 0,
            "rejected_calls": 0
        }
    
    def call(self, func: Callable[..., T], *args, **kwargs) -> T:
        """Execute function with circuit breaker protection"""
        with self._lock:
            self.metrics["total_calls"] += 1
            
            # Check if circuit should transition from OPEN to HALF_OPEN
            if self.state == CircuitState.OPEN:
                if self._should_attempt_reset():
                    self.state = CircuitState.HALF_OPEN
                    logger.info(f"Circuit {self.name} transitioning to HALF_OPEN")
                else:
                    self.metrics["rejected_calls"] += 1
                    raise Exception(f"Circuit breaker {self.name} is OPEN")
        
        try:
            result = func(*args, **kwargs)
            self._on_success()
            return result
        except self.config.expected_exception as e:
            self._on_failure()
            raise e
    
    def _should_attempt_reset(self) -> bool:
        """Check if enough time has passed to try recovery"""
        return (
            self.last_failure_time and 
            datetime.now() >= self.last_failure_time + timedelta(seconds=self.config.recovery_timeout)
        )
    
    def _on_success(self):
        """Handle successful call"""
        with self._lock:
            self.metrics["successful_calls"] += 1
            self.failure_count = 0
            
            if self.state == CircuitState.HALF_OPEN:
                self.success_count += 1
                if self.success_count >= self.config.success_threshold:
                    self.state = CircuitState.CLOSED
                    self.success_count = 0
                    logger.info(f"Circuit {self.name} closed after recovery")
    
    def _on_failure(self):
        """Handle failed call"""
        with self._lock:
            self.metrics["failed_calls"] += 1
            self.failure_count += 1
            self.last_failure_time = datetime.now()
            
            if self.state == CircuitState.HALF_OPEN:
                self.state = CircuitState.OPEN
                logger.warning(f"Circuit {self.name} reopened after failure in HALF_OPEN")
            elif self.failure_count >= self.config.failure_threshold:
                self.state = CircuitState.OPEN
                logger.error(f"Circuit {self.name} opened after {self.failure_count} failures")

@dataclass
class RetryConfig:
    """Configuration for retry with exponential backoff"""
    max_attempts: int = 5
    base_delay: float = 1.0  # seconds
    max_delay: float = 60.0  # seconds
    exponential_base: float = 2.0
    jitter: bool = True

class RetryManager:
    """
    Retry manager with exponential backoff and jitter
    Based on AWS SDK retry strategy and Google SRE practices
    """
    
    def __init__(self, config: RetryConfig):
        self.config = config
    
    def execute_with_retry(self, func: Callable[..., T], *args, **kwargs) -> T:
        """Execute function with retry logic"""
        last_exception = None
        
        for attempt in range(self.config.max_attempts):
            try:
                return func(*args, **kwargs)
            except Exception as e:
                last_exception = e
                if attempt < self.config.max_attempts - 1:
                    delay = self._calculate_delay(attempt)
                    logger.warning(f"Attempt {attempt + 1} failed: {e}. Retrying in {delay:.2f}s")
                    time.sleep(delay)
                else:
                    logger.error(f"All {self.config.max_attempts} attempts failed")
        
        raise last_exception
    
    def _calculate_delay(self, attempt: int) -> float:
        """Calculate delay with exponential backoff and optional jitter"""
        delay = min(
            self.config.base_delay * (self.config.exponential_base ** attempt),
            self.config.max_delay
        )
        
        if self.config.jitter:
            # Add random jitter to prevent thundering herd
            delay = delay * (0.5 + random.random())
        
        return delay

class BulkheadManager:
    """
    Bulkhead pattern implementation for resource isolation
    Based on Netflix Hystrix thread pool isolation
    """
    
    def __init__(self, name: str, max_concurrent: int = 10, queue_size: int = 100):
        self.name = name
        self.max_concurrent = max_concurrent
        self.queue_size = queue_size
        self.semaphore = asyncio.Semaphore(max_concurrent)
        self.queue = deque(maxlen=queue_size)
        self.active_count = 0
        self.metrics = {
            "total_executed": 0,
            "rejected": 0,
            "queued": 0
        }
    
    async def execute(self, coro):
        """Execute coroutine with bulkhead protection"""
        if self.active_count >= self.max_concurrent and len(self.queue) >= self.queue_size:
            self.metrics["rejected"] += 1
            raise Exception(f"Bulkhead {self.name} queue is full")
        
        async with self.semaphore:
            self.active_count += 1
            self.metrics["total_executed"] += 1
            try:
                return await coro
            finally:
                self.active_count -= 1

class HealthChecker:
    """
    Health checking and self-healing capabilities
    Based on Kubernetes health probes and AWS ELB health checks
    """
    
    def __init__(self):
        self.checks = {}
        self.check_results = {}
        self.failure_counts = {}
    
    def register_check(self, name: str, check_func: Callable[[], bool], 
                       critical: bool = False):
        """Register a health check"""
        self.checks[name] = {
            "func": check_func,
            "critical": critical
        }
        self.failure_counts[name] = 0
    
    async def run_health_checks(self) -> dict:
        """Run all registered health checks"""
        results = {}
        overall_health = True
        
        for name, check in self.checks.items():
            try:
                is_healthy = await asyncio.get_event_loop().run_in_executor(
                    None, check["func"]
                )
                results[name] = {
                    "status": "healthy" if is_healthy else "unhealthy",
                    "critical": check["critical"]
                }
                
                if not is_healthy:
                    self.failure_counts[name] += 1
                    if check["critical"]:
                        overall_health = False
                    logger.warning(f"Health check {name} failed")
                else:
                    self.failure_counts[name] = 0
            except Exception as e:
                results[name] = {
                    "status": "error",
                    "error": str(e),
                    "critical": check["critical"]
                }
                self.failure_counts[name] += 1
                if check["critical"]:
                    overall_health = False
                logger.error(f"Health check {name} error: {e}")
        
        results["overall"] = "healthy" if overall_health else "unhealthy"
        results["timestamp"] = datetime.now().isoformat()
        
        self.check_results = results
        return results

class ResilienceOrchestrator:
    """
    Main orchestrator combining all resilience patterns
    Provides unified interface for resilient operations
    """
    
    def __init__(self):
        self.circuit_breakers = {}
        self.retry_manager = RetryManager(RetryConfig())
        self.bulkheads = {}
        self.health_checker = HealthChecker()
        self._setup_default_health_checks()
    
    def _setup_default_health_checks(self):
        """Setup default health checks"""
        self.health_checker.register_check(
            "database",
            self._check_database_health,
            critical=True
        )
        self.health_checker.register_check(
            "selenium",
            self._check_selenium_health,
            critical=False
        )
        self.health_checker.register_check(
            "memory",
            self._check_memory_health,
            critical=True
        )
    
    def _check_database_health(self) -> bool:
        """Check database connectivity"""
        try:
            from database import SessionLocal
            db = SessionLocal()
            db.execute("SELECT 1")
            db.close()
            return True
        except Exception:
            return False
    
    def _check_selenium_health(self) -> bool:
        """Check Selenium availability"""
        try:
            import requests
            response = requests.get("http://selenium-chrome:4444/status", timeout=5)
            return response.status_code == 200
        except Exception:
            return False
    
    def _check_memory_health(self) -> bool:
        """Check memory usage"""
        import psutil
        memory = psutil.virtual_memory()
        return memory.percent < 90  # Alert if memory > 90%
    
    def create_circuit_breaker(self, name: str, 
                              config: Optional[CircuitBreakerConfig] = None):
        """Create a new circuit breaker"""
        if config is None:
            config = CircuitBreakerConfig()
        self.circuit_breakers[name] = CircuitBreaker(name, config)
        return self.circuit_breakers[name]
    
    def create_bulkhead(self, name: str, max_concurrent: int = 10):
        """Create a new bulkhead"""
        self.bulkheads[name] = BulkheadManager(name, max_concurrent)
        return self.bulkheads[name]
    
    def with_resilience(self, operation_name: str):
        """Decorator to apply all resilience patterns to a function"""
        def decorator(func):
            @wraps(func)
            async def async_wrapper(*args, **kwargs):
                # Apply bulkhead if exists
                if operation_name in self.bulkheads:
                    bulkhead = self.bulkheads[operation_name]
                    return await bulkhead.execute(func(*args, **kwargs))
                
                # Apply circuit breaker if exists
                if operation_name in self.circuit_breakers:
                    breaker = self.circuit_breakers[operation_name]
                    return await asyncio.get_event_loop().run_in_executor(
                        None, breaker.call, func, *args, **kwargs
                    )
                
                # Apply retry
                return await asyncio.get_event_loop().run_in_executor(
                    None, self.retry_manager.execute_with_retry, func, *args, **kwargs
                )
            
            @wraps(func)
            def sync_wrapper(*args, **kwargs):
                # Apply circuit breaker if exists
                if operation_name in self.circuit_breakers:
                    breaker = self.circuit_breakers[operation_name]
                    return breaker.call(func, *args, **kwargs)
                
                # Apply retry
                return self.retry_manager.execute_with_retry(func, *args, **kwargs)
            
            # Return appropriate wrapper based on function type
            if asyncio.iscoroutinefunction(func):
                return async_wrapper
            else:
                return sync_wrapper
        
        return decorator
    
    def get_metrics(self) -> dict:
        """Get all resilience metrics"""
        metrics = {
            "circuit_breakers": {},
            "bulkheads": {},
            "health": self.health_checker.check_results
        }
        
        for name, breaker in self.circuit_breakers.items():
            metrics["circuit_breakers"][name] = {
                "state": breaker.state.value,
                "metrics": breaker.metrics
            }
        
        for name, bulkhead in self.bulkheads.items():
            metrics["bulkheads"][name] = {
                "active": bulkhead.active_count,
                "metrics": bulkhead.metrics
            }
        
        return metrics

# Global resilience orchestrator instance
resilience = ResilienceOrchestrator()