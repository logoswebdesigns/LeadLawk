#!/usr/bin/env python3
"""
Celery configuration for resilient job processing
Based on Celery best practices and production recommendations
"""

from celery import Celery, Task
from celery.signals import worker_ready, task_failure, task_success, task_retry
from celery.utils.log import get_task_logger
import os
import time
from datetime import timedelta
import logging

# Configure logging
logger = get_task_logger(__name__)

# Celery configuration based on production best practices
celery_app = Celery('leadlawk')

celery_app.conf.update(
    # Broker settings (Redis)
    broker_url=os.getenv('REDIS_URL', 'redis://localhost:6379/0'),
    result_backend=os.getenv('REDIS_URL', 'redis://localhost:6379/1'),
    
    # Task execution settings
    task_serializer='json',
    accept_content=['json'],
    result_serializer='json',
    timezone='UTC',
    enable_utc=True,
    
    # Task behavior
    task_acks_late=True,  # Acknowledge tasks after completion (reliability)
    task_reject_on_worker_lost=True,  # Re-queue tasks if worker dies
    task_track_started=True,
    task_time_limit=3600,  # 1 hour hard limit
    task_soft_time_limit=3300,  # 55 minutes soft limit
    
    # Retry configuration
    task_default_retry_delay=60,  # 1 minute
    task_max_retries=5,
    
    # Worker configuration
    worker_prefetch_multiplier=1,  # Prevent worker from prefetching too many tasks
    worker_max_tasks_per_child=100,  # Restart worker after 100 tasks (prevent memory leaks)
    worker_disable_rate_limits=False,
    
    # Result backend settings
    result_expires=86400,  # Results expire after 1 day
    
    # Beat scheduler (for periodic tasks)
    beat_schedule={
        'health-check': {
            'task': 'celery_app.health_check_task',
            'schedule': timedelta(seconds=30),
        },
        'cleanup-stale-jobs': {
            'task': 'celery_app.cleanup_stale_jobs',
            'schedule': timedelta(minutes=15),
        },
        'memory-check': {
            'task': 'celery_app.check_memory_usage',
            'schedule': timedelta(minutes=5),
        },
    },
    
    # Queue routing
    task_routes={
        'celery_app.browser_automation_task': {'queue': 'browser'},
        'celery_app.pagespeed_test_task': {'queue': 'pagespeed'},
        'celery_app.database_task': {'queue': 'database'},
    },
    
    # Dead letter queue for failed tasks
    task_dead_letter_exchange='dlx',
    task_dead_letter_routing_key='failed',
)

class ResilientTask(Task):
    """
    Base task class with built-in resilience patterns
    """
    
    autoretry_for = (Exception,)
    retry_kwargs = {'max_retries': 5, 'countdown': 60}
    retry_backoff = True
    retry_backoff_max = 600
    retry_jitter = True
    
    def on_failure(self, exc, task_id, args, kwargs, einfo):
        """Handle task failure"""
        logger.error(f"Task {task_id} failed: {exc}")
        # Send to dead letter queue after max retries
        super().on_failure(exc, task_id, args, kwargs, einfo)
    
    def on_retry(self, exc, task_id, args, kwargs, einfo):
        """Handle task retry"""
        logger.warning(f"Task {task_id} retrying: {exc}")
        super().on_retry(exc, task_id, args, kwargs, einfo)
    
    def on_success(self, retval, task_id, args, kwargs):
        """Handle task success"""
        logger.info(f"Task {task_id} completed successfully")
        super().on_success(retval, task_id, args, kwargs)

# Set default task class
celery_app.Task = ResilientTask

@celery_app.task(bind=True, name='celery_app.browser_automation_task')
def browser_automation_task(self, job_params):
    """
    Resilient browser automation task
    """
    from resilience_manager import resilience
    from browser_automation import BrowserAutomation
    import json
    
    try:
        logger.info(f"Starting browser automation job: {self.request.id}")
        
        # Apply resilience patterns
        @resilience.with_resilience("browser_automation")
        def run_automation():
            automation = BrowserAutomation()
            try:
                result = automation.run_scraping_job(job_params)
                return result
            finally:
                automation.cleanup()
        
        result = run_automation()
        logger.info(f"Browser automation job completed: {self.request.id}")
        return result
        
    except Exception as exc:
        logger.error(f"Browser automation failed: {exc}")
        # Retry with exponential backoff
        raise self.retry(exc=exc, countdown=60 * (2 ** self.request.retries))

@celery_app.task(bind=True, name='celery_app.pagespeed_test_task')
def pagespeed_test_task(self, lead_id, website_url):
    """
    Resilient PageSpeed testing task
    """
    from resilience_manager import resilience
    from pagespeed_service import PageSpeedService
    
    try:
        logger.info(f"Starting PageSpeed test for lead {lead_id}")
        
        @resilience.with_resilience("pagespeed")
        def run_pagespeed():
            service = PageSpeedService()
            return service.test_website(lead_id, website_url)
        
        result = run_pagespeed()
        logger.info(f"PageSpeed test completed for lead {lead_id}")
        return result
        
    except Exception as exc:
        logger.error(f"PageSpeed test failed: {exc}")
        raise self.retry(exc=exc, countdown=120 * (2 ** self.request.retries))

@celery_app.task(name='celery_app.health_check_task')
def health_check_task():
    """
    Periodic health check task
    """
    from resilience_manager import resilience
    import asyncio
    
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    
    try:
        health_status = loop.run_until_complete(resilience.health_checker.run_health_checks())
        
        if health_status["overall"] != "healthy":
            logger.warning(f"Health check failed: {health_status}")
            # Trigger recovery procedures
            trigger_recovery(health_status)
        else:
            logger.debug("Health check passed")
        
        return health_status
    finally:
        loop.close()

@celery_app.task(name='celery_app.cleanup_stale_jobs')
def cleanup_stale_jobs():
    """
    Clean up stale jobs that have been running too long
    """
    from database import SessionLocal
    from models import Lead
    from datetime import datetime, timedelta
    
    db = SessionLocal()
    try:
        # Find jobs older than 2 hours
        stale_time = datetime.utcnow() - timedelta(hours=2)
        
        # Cancel stale browser jobs
        from job_manager import get_all_jobs, cancel_job
        jobs = get_all_jobs()
        
        stale_count = 0
        for job_id, job_info in jobs.items():
            if job_info.get('status') == 'running':
                created_at = job_info.get('created_at')
                if created_at and datetime.fromisoformat(created_at) < stale_time:
                    logger.warning(f"Cancelling stale job: {job_id}")
                    cancel_job(job_id)
                    stale_count += 1
        
        logger.info(f"Cleaned up {stale_count} stale jobs")
        return {"cleaned": stale_count}
        
    finally:
        db.close()

@celery_app.task(name='celery_app.check_memory_usage')
def check_memory_usage():
    """
    Monitor memory usage and trigger cleanup if needed
    """
    import psutil
    import gc
    
    memory = psutil.virtual_memory()
    memory_percent = memory.percent
    
    logger.info(f"Memory usage: {memory_percent}%")
    
    if memory_percent > 80:
        logger.warning(f"High memory usage detected: {memory_percent}%")
        # Force garbage collection
        gc.collect()
        
        # Restart workers if memory is critically high
        if memory_percent > 90:
            logger.error("Critical memory usage - restarting workers")
            celery_app.control.broadcast('pool_restart')
    
    return {"memory_percent": memory_percent}

def trigger_recovery(health_status):
    """
    Trigger recovery procedures based on health status
    """
    if "database" in health_status and health_status["database"]["status"] != "healthy":
        # Database recovery
        logger.error("Database unhealthy - attempting recovery")
        # Implement database recovery logic
    
    if "selenium" in health_status and health_status["selenium"]["status"] != "healthy":
        # Selenium recovery
        logger.error("Selenium unhealthy - restarting container")
        import subprocess
        subprocess.run(["docker", "restart", "selenium-chrome"])
    
    if "memory" in health_status and health_status["memory"]["status"] != "healthy":
        # Memory recovery
        logger.error("Memory unhealthy - forcing cleanup")
        import gc
        gc.collect()

# Signal handlers for monitoring
@worker_ready.connect
def worker_ready_handler(sender, **kwargs):
    """Called when worker is ready"""
    logger.info("Worker ready and accepting tasks")

@task_failure.connect
def task_failure_handler(sender, task_id, exception, **kwargs):
    """Called when task fails"""
    logger.error(f"Task {task_id} failed with {exception}")
    # Could send alerts here

@task_success.connect
def task_success_handler(sender, result, **kwargs):
    """Called when task succeeds"""
    logger.debug(f"Task succeeded with result: {result}")

@task_retry.connect
def task_retry_handler(sender, reason, **kwargs):
    """Called when task is retried"""
    logger.warning(f"Task retrying due to: {reason}")