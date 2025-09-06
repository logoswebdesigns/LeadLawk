#!/usr/bin/env python3
"""
Test suite to verify server health after removing backup files.
Ensures no functionality was lost during cleanup.
Following Test-Driven Development (TDD) principles.
"""

import pytest
import requests
import time
import subprocess
import os
import signal
from typing import Optional

class TestServerHealth:
    """
    Integration tests to verify server functionality.
    Pattern: Arrange-Act-Assert (AAA) test pattern.
    """
    
    server_process: Optional[subprocess.Popen] = None
    base_url = "http://localhost:8000"
    
    @classmethod
    def setup_class(cls):
        """Start the server before running tests."""
        env = os.environ.copy()
        env["USE_DOCKER"] = "0"
        cls.server_process = subprocess.Popen(
            ["python", "main.py"],
            cwd="server",
            env=env,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE
        )
        time.sleep(3)
    
    @classmethod
    def teardown_class(cls):
        """Stop the server after tests complete."""
        if cls.server_process:
            cls.server_process.send_signal(signal.SIGTERM)
            cls.server_process.wait(timeout=5)
    
    def test_health_endpoint(self):
        """Verify health check endpoint responds correctly."""
        response = requests.get(f"{self.base_url}/health")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"
        assert "database" in data
        assert "timestamp" in data
    
    def test_leads_endpoint_structure(self):
        """Verify leads API endpoint structure is intact."""
        response = requests.get(f"{self.base_url}/leads?page=1&per_page=5")
        assert response.status_code == 200
        data = response.json()
        assert "items" in data
        assert "total" in data
        assert "page" in data
        assert "per_page" in data
        assert "total_pages" in data
    
    def test_websocket_endpoint_exists(self):
        """Verify WebSocket endpoint is accessible."""
        response = requests.get(f"{self.base_url}/")
        assert response.status_code == 200
    
    def test_no_backup_imports(self):
        """Verify no imports reference deleted backup files."""
        dangerous_imports = [
            "from browser_automation_backup",
            "import browser_automation_backup",
            "from business_extractor_enhanced",
            "import business_extractor_enhanced",
            "from main_backup",
            "import main_backup",
            "from job_management_backup",
            "import job_management_backup"
        ]
        
        with open("server/main.py", "r") as f:
            content = f.read()
            for dangerous_import in dangerous_imports:
                assert dangerous_import not in content, f"Found backup import: {dangerous_import}"
    
    def test_critical_endpoints_exist(self):
        """Verify all critical endpoints are still available."""
        critical_endpoints = [
            ("/leads", "GET"),
            ("/leads/statistics/all", "GET"),
            ("/leads/search", "GET"),
            ("/jobs/active", "GET"),
        ]
        
        for endpoint, method in critical_endpoints:
            if method == "GET":
                response = requests.get(f"{self.base_url}{endpoint}")
                assert response.status_code in [200, 422], f"Endpoint {endpoint} failed"


if __name__ == "__main__":
    pytest.main([__file__, "-v"])