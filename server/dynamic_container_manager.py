#!/usr/bin/env python3
"""
Dynamic container management for parallel Selenium execution.
Each job gets its own dedicated Chrome container that spins up/down as needed.
"""

import os
import uuid
import time
import docker
import psutil
import logging
from typing import Dict, Optional, Any, Tuple
from datetime import datetime
from threading import Lock
from selenium import webdriver
from selenium.webdriver.chrome.options import Options

logger = logging.getLogger(__name__)

class DynamicContainerManager:
    """Manages individual Selenium containers for each job"""
    
    def __init__(self, max_containers: int = 10, memory_threshold: float = 80.0, cpu_threshold: float = 90.0):
        self.docker_client = docker.from_env()
        self.active_containers = {}  # job_id -> container mapping
        self.network_name = "leadloq-network"
        self.max_containers = max_containers
        self.memory_threshold = memory_threshold  # Max % memory usage
        self.cpu_threshold = cpu_threshold  # Max % CPU usage
        self.container_lock = Lock()
        self.queued_jobs = []  # Jobs waiting for resources
        self._ensure_network_exists()
        
    def _ensure_network_exists(self):
        """Ensure the Docker network exists"""
        try:
            self.docker_client.networks.get(self.network_name)
        except docker.errors.NotFound:
            logger.info(f"Creating Docker network: {self.network_name}")
            self.docker_client.networks.create(self.network_name, driver="bridge")
    
    def check_system_resources(self) -> Tuple[bool, str]:
        """
        Check if system has enough resources for a new container.
        Returns (can_spawn, reason)
        """
        # Check memory usage
        memory = psutil.virtual_memory()
        memory_percent = memory.percent
        
        # Check CPU usage (average over 1 second)
        cpu_percent = psutil.cpu_percent(interval=1)
        
        # Check Docker resources
        running_containers = len([c for c in self.active_containers.values() if c.status == 'running'])
        
        if memory_percent > self.memory_threshold:
            return False, f"Memory usage too high: {memory_percent:.1f}% (threshold: {self.memory_threshold}%)"
        
        if cpu_percent > self.cpu_threshold:
            return False, f"CPU usage too high: {cpu_percent:.1f}% (threshold: {self.cpu_threshold}%)"
        
        if running_containers >= self.max_containers:
            return False, f"Maximum containers reached: {running_containers}/{self.max_containers}"
        
        # Calculate available memory in GB
        available_gb = memory.available / (1024 ** 3)
        if available_gb < 2.0:  # Need at least 2GB for a new container
            return False, f"Insufficient memory: {available_gb:.1f}GB available (need 2GB)"
        
        return True, "Resources available"
    
    def spawn_selenium_container(self, job_id: str, wait_for_resources: bool = True) -> Dict[str, Any]:
        """
        Spawn a dedicated Selenium container for a specific job.
        Returns connection details or queues the job if resources unavailable.
        """
        container_name = f"selenium-{job_id[:8]}"
        
        with self.container_lock:
            # Check if container already exists
            if job_id in self.active_containers:
                logger.warning(f"Container for job {job_id} already exists")
                return self._get_container_info(job_id)
            
            # Check system resources
            can_spawn, reason = self.check_system_resources()
            
            if not can_spawn:
                if wait_for_resources:
                    logger.warning(f"⚠️ Cannot spawn container for job {job_id}: {reason}")
                    logger.info(f"🕓 Queuing job {job_id} - waiting for resources")
                    self.queued_jobs.append(job_id)
                    return {
                        "status": "queued",
                        "reason": reason,
                        "position": len(self.queued_jobs),
                        "active_containers": len(self.active_containers)
                    }
                else:
                    raise Exception(f"Cannot spawn container: {reason}")
            
            logger.info(f"🚀 Spawning Selenium container for job {job_id}")
        
        try:
            # Determine architecture for image selection
            import platform
            is_arm = platform.machine().lower() in ['arm64', 'aarch64']
            image = "seleniarm/standalone-chromium:latest" if is_arm else "selenium/standalone-chromium:latest"
            
            # Create and start container
            container = self.docker_client.containers.run(
                image=image,
                name=container_name,
                detach=True,
                remove=False,  # Don't auto-remove, we'll clean up manually
                network=self.network_name,
                environment={
                    "SE_NODE_MAX_SESSIONS": "1",  # One session per container
                    "SE_NODE_SESSION_TIMEOUT": "300",
                    "SE_SCREEN_WIDTH": "1920",
                    "SE_SCREEN_HEIGHT": "1080",
                },
                shm_size="2g",
                ports={'4444/tcp': None},  # Random port assignment
                labels={
                    "job_id": job_id,
                    "created_at": datetime.utcnow().isoformat(),
                    "managed_by": "leadloq"
                }
            )
            
            # Store container reference
            self.active_containers[job_id] = container
            
            # Wait for container to be ready
            if not self._wait_for_container_ready(container, timeout=30):
                raise Exception("Container failed to become ready")
            
            # Get container info
            container.reload()
            info = self._get_container_info(job_id)
            
            logger.info(f"✅ Container {container_name} ready at {info['url']}")
            return info
            
        except Exception as e:
            logger.error(f"❌ Failed to spawn container for job {job_id}: {str(e)}")
            # Clean up on failure
            self.destroy_selenium_container(job_id)
            raise
    
    def _wait_for_container_ready(self, container, timeout: int = 30) -> bool:
        """Wait for Selenium to be ready in the container"""
        import requests
        from requests.adapters import HTTPAdapter
        from urllib3.util.retry import Retry
        
        session = requests.Session()
        retry = Retry(total=0, backoff_factor=0.1)
        adapter = HTTPAdapter(max_retries=retry)
        session.mount('http://', adapter)
        
        start_time = time.time()
        container.reload()
        
        # Get the port mapping
        ports = container.attrs['NetworkSettings']['Ports']
        if '4444/tcp' not in ports or not ports['4444/tcp']:
            logger.error("Container has no port mapping")
            return False
        
        host_port = ports['4444/tcp'][0]['HostPort']
        health_url = f"http://localhost:{host_port}/wd/hub/status"
        
        while time.time() - start_time < timeout:
            try:
                response = session.get(health_url, timeout=1)
                if response.status_code == 200:
                    data = response.json()
                    if data.get('value', {}).get('ready', False):
                        return True
            except:
                pass
            time.sleep(0.5)
        
        return False
    
    def _get_container_info(self, job_id: str) -> Dict[str, Any]:
        """Get connection information for a container"""
        if job_id not in self.active_containers:
            raise ValueError(f"No container found for job {job_id}")
        
        container = self.active_containers[job_id]
        container.reload()
        
        # Get port mapping
        ports = container.attrs['NetworkSettings']['Ports']
        host_port = ports['4444/tcp'][0]['HostPort'] if '4444/tcp' in ports else None
        
        # Get container IP for internal network communication
        networks = container.attrs['NetworkSettings']['Networks']
        container_ip = networks.get(self.network_name, {}).get('IPAddress')
        
        return {
            "container_id": container.id[:12],
            "container_name": container.name,
            "url": f"http://localhost:{host_port}/wd/hub",
            "internal_url": f"http://{container_ip}:4444/wd/hub" if container_ip else None,
            "host_port": host_port,
            "status": container.status,
        }
    
    def destroy_selenium_container(self, job_id: str) -> bool:
        """Destroy a Selenium container when job completes"""
        try:
            with self.container_lock:
                if job_id not in self.active_containers:
                    logger.warning(f"No container to destroy for job {job_id}")
                    return False
                
                container = self.active_containers[job_id]
                container_name = container.name
                
                logger.info(f"🔥 Destroying container {container_name} for job {job_id}")
                
                # Stop and remove container
                container.stop(timeout=5)
                container.remove(force=True)
                
                # Remove from tracking
                del self.active_containers[job_id]
                
                logger.info(f"✅ Container {container_name} destroyed")
                
                # Check if we can process queued jobs
                self._process_queue()
                
                return True
            
        except Exception as e:
            logger.error(f"❌ Failed to destroy container for job {job_id}: {str(e)}")
            # Try to force remove
            try:
                if job_id in self.active_containers:
                    self.active_containers[job_id].remove(force=True)
                    del self.active_containers[job_id]
            except:
                pass
            return False
    
    def cleanup_orphaned_containers(self):
        """Clean up any orphaned Selenium containers"""
        try:
            containers = self.docker_client.containers.list(
                all=True,
                filters={"label": "managed_by=leadloq"}
            )
            
            for container in containers:
                labels = container.labels
                job_id = labels.get("job_id")
                created_at = labels.get("created_at")
                
                # Remove containers older than 1 hour or in exited state
                if container.status == "exited":
                    logger.info(f"Removing exited container: {container.name}")
                    container.remove(force=True)
                elif created_at:
                    created_time = datetime.fromisoformat(created_at)
                    age_hours = (datetime.utcnow() - created_time).total_seconds() / 3600
                    if age_hours > 1:
                        logger.info(f"Removing old container: {container.name} (age: {age_hours:.1f} hours)")
                        container.stop(timeout=5)
                        container.remove(force=True)
                        
        except Exception as e:
            logger.error(f"Error during cleanup: {str(e)}")
    
    def _process_queue(self):
        """Process queued jobs when resources become available"""
        if not self.queued_jobs:
            return
        
        can_spawn, reason = self.check_system_resources()
        if can_spawn and self.queued_jobs:
            job_id = self.queued_jobs.pop(0)
            logger.info(f"🎆 Processing queued job {job_id} - resources now available")
            # The job executor will retry spawning
    
    def get_container_stats(self) -> Dict[str, Any]:
        """Get statistics about running containers and system resources"""
        try:
            all_containers = self.docker_client.containers.list(
                all=True,
                filters={"label": "managed_by=leadloq"}
            )
            
            running = [c for c in all_containers if c.status == "running"]
            exited = [c for c in all_containers if c.status == "exited"]
            
            # Get system resources
            memory = psutil.virtual_memory()
            cpu_percent = psutil.cpu_percent(interval=0.1)
            
            return {
                "active_jobs": len(self.active_containers),
                "running_containers": len(running),
                "exited_containers": len(exited),
                "total_containers": len(all_containers),
                "queued_jobs": len(self.queued_jobs),
                "max_containers": self.max_containers,
                "system_resources": {
                    "memory_percent": memory.percent,
                    "memory_available_gb": memory.available / (1024 ** 3),
                    "cpu_percent": cpu_percent,
                    "can_spawn_more": self.check_system_resources()[0]
                },
                "containers": [
                    {
                        "name": c.name,
                        "status": c.status,
                        "job_id": c.labels.get("job_id", "unknown"),
                        "created_at": c.labels.get("created_at", "unknown")
                    }
                    for c in all_containers
                ]
            }
        except Exception as e:
            return {"error": str(e)}
    
    def create_webdriver(self, job_id: str) -> webdriver.Remote:
        """Create a WebDriver connected to the job's container"""
        info = self._get_container_info(job_id)
        
        chrome_options = Options()
        chrome_options.add_argument('--no-sandbox')
        chrome_options.add_argument('--disable-dev-shm-usage')
        chrome_options.add_argument('--disable-blink-features=AutomationControlled')
        chrome_options.add_experimental_option("excludeSwitches", ["enable-automation"])
        chrome_options.add_experimental_option('useAutomationExtension', False)
        
        # Use internal URL if running in Docker, otherwise use localhost
        url = info['internal_url'] if os.getenv('USE_DOCKER') else info['url']
        
        driver = webdriver.Remote(
            command_executor=url,
            options=chrome_options
        )
        
        return driver
    
    def shutdown_all(self):
        """Shutdown all managed containers"""
        logger.info("Shutting down all managed containers...")
        job_ids = list(self.active_containers.keys())
        for job_id in job_ids:
            self.destroy_selenium_container(job_id)
        logger.info("All containers shut down")


# Global instance with configurable limits
# Adjust these based on your system capacity
MAX_CONTAINERS = int(os.getenv('MAX_SELENIUM_CONTAINERS', '10'))
MEMORY_THRESHOLD = float(os.getenv('MEMORY_THRESHOLD_PERCENT', '80'))
CPU_THRESHOLD = float(os.getenv('CPU_THRESHOLD_PERCENT', '90'))

try:
    container_manager = DynamicContainerManager(
        max_containers=MAX_CONTAINERS,
        memory_threshold=MEMORY_THRESHOLD,
        cpu_threshold=CPU_THRESHOLD
    )
except Exception as e:
    print(f"Warning: Could not initialize container manager: {e}")
    container_manager = None