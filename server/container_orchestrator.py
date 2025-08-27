#!/usr/bin/env python3
"""
Dynamic Selenium Container Orchestrator
Handles scaling Selenium Chrome containers up and down based on demand
Follows Docker Compose scaling best practices
"""

import asyncio
import docker
import logging
import os
import time
from typing import Dict, List, Optional, Set
from dataclasses import dataclass
from datetime import datetime, timedelta
from contextlib import asynccontextmanager

logger = logging.getLogger(__name__)

@dataclass
class SeleniumContainer:
    """Represents a Selenium Chrome container instance"""
    container_id: str
    container_name: str
    hub_url: str
    port: int
    status: str = "running"
    created_at: datetime = None
    last_used: datetime = None
    current_jobs: Set[str] = None
    
    def __post_init__(self):
        if self.created_at is None:
            self.created_at = datetime.utcnow()
        if self.current_jobs is None:
            self.current_jobs = set()

class SeleniumOrchestrator:
    """
    Manages dynamic scaling of Selenium Chrome containers
    Follows official Docker Compose scaling patterns
    """
    
    def __init__(self, 
                 min_instances: int = 1,
                 max_instances: int = 5,
                 scale_up_threshold: int = 2,  # Scale up when avg jobs per container > this
                 scale_down_delay: int = 300,  # Wait 5 minutes before scaling down
                 container_timeout: int = 900,  # Remove idle containers after 15 minutes
                 base_port: int = 4444):
        
        self.min_instances = min_instances
        self.max_instances = max_instances
        self.scale_up_threshold = scale_up_threshold
        self.scale_down_delay = scale_down_delay
        self.container_timeout = container_timeout
        self.base_port = base_port
        
        # Try to connect to Docker, but gracefully handle failure
        self.docker_available = False
        self.docker_client = None
        self.containers: Dict[str, SeleniumContainer] = {}
        self.network_name = "leadloq-network"
        self.container_prefix = "selenium-chrome"
        
        try:
            self.docker_client = docker.from_env()
            # Test connection
            self.docker_client.ping()
            self.docker_available = True
            logger.info("✅ Docker client connected successfully")
            # Ensure network exists
            self._ensure_network_exists()
        except Exception as e:
            logger.warning(f"⚠️ Docker not available for container orchestration: {e}")
            logger.info("📝 Falling back to single container mode")
            self.docker_available = False
    
    def _ensure_network_exists(self):
        """Ensure the Docker network exists"""
        if not self.docker_available:
            return
            
        try:
            self.docker_client.networks.get(self.network_name)
        except docker.errors.NotFound:
            logger.info(f"Creating Docker network: {self.network_name}")
            self.docker_client.networks.create(self.network_name, driver="bridge")
        except Exception as e:
            logger.warning(f"Could not ensure network exists: {e}")
    
    def _get_next_port(self) -> int:
        """Get the next available port for a new container"""
        used_ports = {container.port for container in self.containers.values()}
        for port in range(self.base_port, self.base_port + 100):
            if port not in used_ports:
                return port
        raise RuntimeError("No available ports for new Selenium containers")
    
    def _generate_container_name(self) -> str:
        """Generate a unique container name"""
        timestamp = int(time.time())
        instance_num = len(self.containers) + 1
        return f"{self.container_prefix}-{instance_num}-{timestamp}"
    
    async def create_container(self) -> SeleniumContainer:
        """
        Create a new Selenium Chrome container
        Following official Selenium Docker image patterns
        """
        if not self.docker_available:
            raise RuntimeError("Docker not available for container orchestration")
            
        if len(self.containers) >= self.max_instances:
            raise RuntimeError(f"Maximum instances ({self.max_instances}) reached")
        
        port = self._get_next_port()
        container_name = self._generate_container_name()
        
        # Container configuration following Selenium standalone image best practices
        container_config = {
            "image": "selenium/standalone-chromium:latest",
            "name": container_name,
            "ports": {
                "4444/tcp": port,  # Selenium hub port
                "7900/tcp": None,  # VNC port (dynamic)
            },
            "environment": {
                "SE_NODE_MAX_SESSIONS": "3",
                "SE_NODE_SESSION_TIMEOUT": "120",
                "SE_VNC_PASSWORD": "secret",
                "SE_START_VNC": "true",
                "SE_SCREEN_WIDTH": "1920",
                "SE_SCREEN_HEIGHT": "1080",
            },
            "volumes": {
                "/app/screenshots": {"bind": "/screenshots", "mode": "rw"}
            },
            "shm_size": "2gb",
            "detach": True,
            "restart_policy": {"Name": "unless-stopped"},
            "network": self.network_name,
        }
        
        try:
            logger.info(f"Creating Selenium container: {container_name} on port {port}")
            docker_container = self.docker_client.containers.run(**container_config)
            
            # Wait for container to be ready
            await self._wait_for_container_ready(docker_container.id, port)
            
            hub_url = f"http://{container_name}:4444/wd/hub"
            
            selenium_container = SeleniumContainer(
                container_id=docker_container.id,
                container_name=container_name,
                hub_url=hub_url,
                port=port
            )
            
            self.containers[docker_container.id] = selenium_container
            logger.info(f"✅ Selenium container created: {container_name} -> {hub_url}")
            
            return selenium_container
            
        except Exception as e:
            logger.error(f"❌ Failed to create Selenium container: {e}")
            raise
    
    async def _wait_for_container_ready(self, container_id: str, port: int, timeout: int = 30):
        """Wait for Selenium container to be ready to accept connections"""
        import aiohttp
        
        start_time = time.time()
        container_url = f"http://localhost:{port}/wd/hub/status"
        
        while time.time() - start_time < timeout:
            try:
                async with aiohttp.ClientSession() as session:
                    async with session.get(container_url, timeout=3) as response:
                        if response.status == 200:
                            data = await response.json()
                            if data.get("value", {}).get("ready", False):
                                logger.info(f"Container {container_id[:12]} ready on port {port}")
                                return
            except Exception:
                pass  # Expected during startup
            
            await asyncio.sleep(2)
        
        raise TimeoutException(f"Container {container_id[:12]} not ready within {timeout}s")
    
    async def remove_container(self, container_id: str):
        """Remove a Selenium container"""
        if container_id not in self.containers:
            return
        
        container = self.containers[container_id]
        
        try:
            docker_container = self.docker_client.containers.get(container_id)
            logger.info(f"Removing Selenium container: {container.container_name}")
            
            # Stop and remove container
            docker_container.stop(timeout=10)
            docker_container.remove()
            
            del self.containers[container_id]
            logger.info(f"✅ Selenium container removed: {container.container_name}")
            
        except docker.errors.NotFound:
            # Container already removed
            del self.containers[container_id]
        except Exception as e:
            logger.error(f"❌ Failed to remove container {container.container_name}: {e}")
    
    def assign_job_to_container(self, job_id: str) -> Optional[SeleniumContainer]:
        """
        Assign a job to the least loaded available container
        Returns the assigned container or None if all are busy
        """
        if not self.containers:
            return None
        
        # Find container with least current jobs
        available_containers = [
            c for c in self.containers.values() 
            if c.status == "running" and len(c.current_jobs) < 3  # Max 3 sessions per container
        ]
        
        if not available_containers:
            return None
        
        # Choose least loaded container
        chosen_container = min(available_containers, key=lambda c: len(c.current_jobs))
        chosen_container.current_jobs.add(job_id)
        chosen_container.last_used = datetime.utcnow()
        
        logger.info(f"Job {job_id} assigned to container {chosen_container.container_name}")
        return chosen_container
    
    def release_job_from_container(self, job_id: str):
        """Release a job from its assigned container"""
        for container in self.containers.values():
            if job_id in container.current_jobs:
                container.current_jobs.remove(job_id)
                logger.info(f"Job {job_id} released from container {container.container_name}")
                break
    
    async def scale_up(self, target_instances: Optional[int] = None) -> List[SeleniumContainer]:
        """Scale up Selenium containers"""
        current_count = len(self.containers)
        target_count = target_instances or min(current_count + 1, self.max_instances)
        
        if target_count <= current_count:
            return []
        
        new_containers = []
        for _ in range(target_count - current_count):
            try:
                container = await self.create_container()
                new_containers.append(container)
            except Exception as e:
                logger.error(f"Failed to scale up: {e}")
                break
        
        logger.info(f"🔄 Scaled up from {current_count} to {len(self.containers)} containers")
        return new_containers
    
    async def scale_down(self, target_instances: Optional[int] = None):
        """Scale down Selenium containers"""
        current_count = len(self.containers)
        target_count = target_instances or max(current_count - 1, self.min_instances)
        
        if target_count >= current_count:
            return
        
        # Find containers to remove (prioritize idle containers)
        containers_to_remove = []
        idle_containers = [
            c for c in self.containers.values()
            if len(c.current_jobs) == 0 and 
            c.last_used and (datetime.utcnow() - c.last_used).total_seconds() > self.scale_down_delay
        ]
        
        # Sort by last used (oldest first)
        idle_containers.sort(key=lambda c: c.last_used or c.created_at)
        
        containers_to_remove = idle_containers[:current_count - target_count]
        
        for container in containers_to_remove:
            await self.remove_container(container.container_id)
        
        logger.info(f"🔄 Scaled down from {current_count} to {len(self.containers)} containers")
    
    async def auto_scale(self):
        """Automatically scale containers based on current load"""
        if not self.containers:
            # No containers exist, create minimum
            await self.scale_up(self.min_instances)
            return
        
        # Calculate average jobs per container
        total_jobs = sum(len(c.current_jobs) for c in self.containers.values())
        avg_jobs_per_container = total_jobs / len(self.containers) if self.containers else 0
        
        # Scale up if average load is high
        if avg_jobs_per_container > self.scale_up_threshold and len(self.containers) < self.max_instances:
            await self.scale_up()
        
        # Scale down if we have idle containers
        elif len(self.containers) > self.min_instances:
            idle_containers = [
                c for c in self.containers.values()
                if len(c.current_jobs) == 0 and 
                c.last_used and (datetime.utcnow() - c.last_used).total_seconds() > self.container_timeout
            ]
            
            if idle_containers:
                await self.scale_down()
    
    async def cleanup_stale_containers(self):
        """Remove containers that have been idle for too long"""
        now = datetime.utcnow()
        stale_containers = [
            c for c in self.containers.values()
            if len(c.current_jobs) == 0 and 
            c.last_used and (now - c.last_used).total_seconds() > self.container_timeout and
            len(self.containers) > self.min_instances
        ]
        
        for container in stale_containers:
            await self.remove_container(container.container_id)
    
    def get_available_container(self, job_id: str) -> Optional[str]:
        """Get an available Selenium Hub URL for a job"""
        if not self.docker_available:
            # Fall back to the default selenium container
            return os.environ.get('SELENIUM_HUB_URL', 'http://selenium-chrome:4444/wd/hub')
            
        container = self.assign_job_to_container(job_id)
        return container.hub_url if container else None
    
    def get_stats(self) -> Dict:
        """Get orchestrator statistics"""
        return {
            "total_containers": len(self.containers),
            "min_instances": self.min_instances,
            "max_instances": self.max_instances,
            "containers": [
                {
                    "id": c.container_id[:12],
                    "name": c.container_name,
                    "port": c.port,
                    "current_jobs": len(c.current_jobs),
                    "status": c.status,
                    "created_at": c.created_at.isoformat(),
                    "last_used": c.last_used.isoformat() if c.last_used else None,
                }
                for c in self.containers.values()
            ]
        }

# Global orchestrator instance - will be initialized on startup
selenium_orchestrator = None

async def initialize_orchestrator():
    """Initialize the orchestrator with minimum instances"""
    global selenium_orchestrator
    
    logger.info("🚀 Initializing Selenium Orchestrator")
    selenium_orchestrator = SeleniumOrchestrator()
    
    if selenium_orchestrator.docker_available:
        await selenium_orchestrator.scale_up(selenium_orchestrator.min_instances)
        # Start background auto-scaling task
        asyncio.create_task(auto_scale_task())
    else:
        logger.info("📝 Running in single-container mode (Docker not available)")

async def auto_scale_task():
    """Background task for auto-scaling containers"""
    if not selenium_orchestrator or not selenium_orchestrator.docker_available:
        return
        
    while True:
        try:
            await selenium_orchestrator.auto_scale()
            await selenium_orchestrator.cleanup_stale_containers()
        except Exception as e:
            logger.error(f"Auto-scale task error: {e}")
        
        await asyncio.sleep(30)  # Check every 30 seconds

@asynccontextmanager
async def get_selenium_container(job_id: str):
    """Context manager to get and release a Selenium container for a job"""
    hub_url = None
    try:
        if not selenium_orchestrator:
            # Fallback to default container
            hub_url = os.environ.get('SELENIUM_HUB_URL', 'http://selenium-chrome:4444/wd/hub')
        elif not selenium_orchestrator.docker_available:
            # Docker not available, use default container
            hub_url = selenium_orchestrator.get_available_container(job_id)
        else:
            # Try to get existing container or create new ones if needed
            hub_url = selenium_orchestrator.get_available_container(job_id)
            
            if not hub_url:
                # No available containers, try to scale up
                await selenium_orchestrator.scale_up()
                hub_url = selenium_orchestrator.get_available_container(job_id)
        
        if not hub_url:
            # Final fallback
            hub_url = os.environ.get('SELENIUM_HUB_URL', 'http://selenium-chrome:4444/wd/hub')
        
        logger.info(f"Job {job_id} using Selenium hub: {hub_url}")
        yield hub_url
        
    finally:
        if hub_url and selenium_orchestrator and selenium_orchestrator.docker_available:
            selenium_orchestrator.release_job_from_container(job_id)