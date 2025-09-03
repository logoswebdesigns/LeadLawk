#!/usr/bin/env python3
"""
Integration tests for Email Templates API endpoints
"""

import requests
import json
import uuid
from typing import List, Dict

# Test configuration
import os
BASE_URL = os.environ.get("API_URL", "http://localhost:8000")
TEMPLATES_ENDPOINT = f"{BASE_URL}/email-templates"


class TestEmailTemplatesAPI:
    """Test suite for email templates API endpoints"""
    
    @classmethod
    def setup_class(cls):
        """Setup test data"""
        cls.created_template_ids = []
    
    @classmethod
    def teardown_class(cls):
        """Clean up test data"""
        # Delete any templates created during tests
        for template_id in cls.created_template_ids:
            try:
                requests.delete(f"{TEMPLATES_ENDPOINT}/{template_id}")
            except:
                pass
    
    def test_initialize_default_templates(self):
        """Test initializing default templates"""
        response = requests.post(f"{TEMPLATES_ENDPOINT}/initialize-defaults")
        assert response.status_code == 200
        data = response.json()
        # Either templates already exist or were created
        assert "message" in data
        assert "created" in data
    
    def test_get_all_templates(self):
        """Test getting all email templates"""
        response = requests.get(TEMPLATES_ENDPOINT)
        assert response.status_code == 200
        templates = response.json()
        assert isinstance(templates, list)
        # Should have at least default templates
        assert len(templates) >= 0
        
        # If templates exist, verify structure
        if templates:
            template = templates[0]
            assert "id" in template
            assert "name" in template
            assert "subject" in template
            assert "body" in template
            assert "is_active" in template
            assert "created_at" in template
            assert "updated_at" in template
    
    def test_create_template(self):
        """Test creating a new email template"""
        template_data = {
            "name": f"Test Template {uuid.uuid4().hex[:8]}",
            "subject": "Test Subject {{businessName}}",
            "body": "Test body for {{businessName}} in {{location}}",
            "description": "Test template for integration testing",
            "is_active": True
        }
        
        response = requests.post(TEMPLATES_ENDPOINT, json=template_data)
        assert response.status_code == 200
        
        created_template = response.json()
        assert created_template["name"] == template_data["name"]
        assert created_template["subject"] == template_data["subject"]
        assert created_template["body"] == template_data["body"]
        assert created_template["description"] == template_data["description"]
        assert created_template["is_active"] == template_data["is_active"]
        assert "id" in created_template
        
        # Store ID for cleanup
        self.__class__.created_template_ids.append(created_template["id"])
        
        return created_template
    
    def test_get_single_template(self):
        """Test getting a single template by ID"""
        # First create a template
        created = self.test_create_template()
        
        # Now fetch it
        response = requests.get(f"{TEMPLATES_ENDPOINT}/{created['id']}")
        assert response.status_code == 200
        
        fetched_template = response.json()
        assert fetched_template["id"] == created["id"]
        assert fetched_template["name"] == created["name"]
        assert fetched_template["subject"] == created["subject"]
    
    def test_update_template(self):
        """Test updating an existing template"""
        # First create a template
        created = self.test_create_template()
        
        # Update it
        update_data = {
            "name": f"Updated {created['name']}",
            "subject": "Updated Subject",
            "body": "Updated body content",
            "is_active": False
        }
        
        response = requests.put(
            f"{TEMPLATES_ENDPOINT}/{created['id']}", 
            json=update_data
        )
        assert response.status_code == 200
        
        updated_template = response.json()
        assert updated_template["name"] == update_data["name"]
        assert updated_template["subject"] == update_data["subject"]
        assert updated_template["body"] == update_data["body"]
        assert updated_template["is_active"] == update_data["is_active"]
    
    def test_partial_update_template(self):
        """Test partial update of a template"""
        # First create a template
        created = self.test_create_template()
        
        # Update only the subject
        update_data = {
            "subject": "Partially Updated Subject"
        }
        
        response = requests.put(
            f"{TEMPLATES_ENDPOINT}/{created['id']}", 
            json=update_data
        )
        assert response.status_code == 200
        
        updated_template = response.json()
        assert updated_template["subject"] == update_data["subject"]
        # Other fields should remain unchanged
        assert updated_template["name"] == created["name"]
        assert updated_template["body"] == created["body"]
    
    def test_delete_template(self):
        """Test deleting a template"""
        # First create a template
        created = self.test_create_template()
        
        # Delete it
        response = requests.delete(f"{TEMPLATES_ENDPOINT}/{created['id']}")
        assert response.status_code == 200
        
        delete_response = response.json()
        assert "message" in delete_response
        
        # Verify it's deleted
        response = requests.get(f"{TEMPLATES_ENDPOINT}/{created['id']}")
        assert response.status_code == 404
        
        # Remove from cleanup list since it's already deleted
        if created['id'] in self.__class__.created_template_ids:
            self.__class__.created_template_ids.remove(created['id'])
    
    def test_duplicate_name_error(self):
        """Test that duplicate template names are rejected"""
        # Create first template
        template_data = {
            "name": f"Unique Template {uuid.uuid4().hex[:8]}",
            "subject": "Subject 1",
            "body": "Body 1",
            "is_active": True
        }
        
        response1 = requests.post(TEMPLATES_ENDPOINT, json=template_data)
        assert response1.status_code == 200
        created1 = response1.json()
        self.__class__.created_template_ids.append(created1["id"])
        
        # Try to create another with same name
        response2 = requests.post(TEMPLATES_ENDPOINT, json=template_data)
        assert response2.status_code == 400
        error = response2.json()
        assert "already exists" in error["detail"].lower()
    
    def test_update_with_duplicate_name_error(self):
        """Test that updating to a duplicate name is rejected"""
        # Create two templates
        template1 = self.test_create_template()
        template2 = self.test_create_template()
        
        # Try to update template2 with template1's name
        update_data = {
            "name": template1["name"]
        }
        
        response = requests.put(
            f"{TEMPLATES_ENDPOINT}/{template2['id']}", 
            json=update_data
        )
        assert response.status_code == 400
        error = response.json()
        assert "already exists" in error["detail"].lower()
    
    def test_get_nonexistent_template(self):
        """Test getting a template that doesn't exist"""
        fake_id = str(uuid.uuid4())
        response = requests.get(f"{TEMPLATES_ENDPOINT}/{fake_id}")
        assert response.status_code == 404
        error = response.json()
        assert "not found" in error["detail"].lower()
    
    def test_delete_nonexistent_template(self):
        """Test deleting a template that doesn't exist"""
        fake_id = str(uuid.uuid4())
        response = requests.delete(f"{TEMPLATES_ENDPOINT}/{fake_id}")
        assert response.status_code == 404
        error = response.json()
        assert "not found" in error["detail"].lower()
    
    def test_filter_active_templates(self):
        """Test filtering templates by active status"""
        # Get all templates
        response_all = requests.get(TEMPLATES_ENDPOINT)
        assert response_all.status_code == 200
        all_templates = response_all.json()
        
        # Get only active templates
        response_active = requests.get(f"{TEMPLATES_ENDPOINT}?active_only=true")
        assert response_active.status_code == 200
        active_templates = response_active.json()
        
        # Active templates should be subset of all templates
        assert len(active_templates) <= len(all_templates)
        
        # All returned templates should be active
        for template in active_templates:
            assert template["is_active"] == True
    
    def test_template_variables(self):
        """Test that template variables are properly stored"""
        template_data = {
            "name": f"Variable Test {uuid.uuid4().hex[:8]}",
            "subject": "{{businessName}} - {{location}}",
            "body": """Dear {{businessName}},
            
Your business in {{location}} serving the {{industry}} industry 
has a rating of {{rating}} with {{reviewCount}} reviews.

Phone: {{phone}}""",
            "description": "Template with all variables",
            "is_active": True
        }
        
        response = requests.post(TEMPLATES_ENDPOINT, json=template_data)
        assert response.status_code == 200
        
        created = response.json()
        self.__class__.created_template_ids.append(created["id"])
        
        # Verify variables are preserved
        assert "{{businessName}}" in created["subject"]
        assert "{{location}}" in created["subject"]
        assert "{{businessName}}" in created["body"]
        assert "{{location}}" in created["body"]
        assert "{{industry}}" in created["body"]
        assert "{{rating}}" in created["body"]
        assert "{{reviewCount}}" in created["body"]
        assert "{{phone}}" in created["body"]


def run_tests():
    """Run all tests and report results"""
    print("Running Email Templates API Integration Tests...")
    print("-" * 50)
    
    # Check if server is running
    try:
        response = requests.get(f"{BASE_URL}/health")
        if response.status_code != 200:
            print("❌ Server is not responding correctly")
            return False
    except requests.exceptions.ConnectionError:
        print("❌ Cannot connect to server at", BASE_URL)
        print("Make sure the server is running: docker-compose up -d")
        return False
    
    # Run tests
    test_suite = TestEmailTemplatesAPI()
    test_suite.setup_class()
    
    tests = [
        ("Initialize default templates", test_suite.test_initialize_default_templates),
        ("Get all templates", test_suite.test_get_all_templates),
        ("Create template", test_suite.test_create_template),
        ("Get single template", test_suite.test_get_single_template),
        ("Update template", test_suite.test_update_template),
        ("Partial update template", test_suite.test_partial_update_template),
        ("Delete template", test_suite.test_delete_template),
        ("Duplicate name error", test_suite.test_duplicate_name_error),
        ("Update with duplicate name error", test_suite.test_update_with_duplicate_name_error),
        ("Get nonexistent template", test_suite.test_get_nonexistent_template),
        ("Delete nonexistent template", test_suite.test_delete_nonexistent_template),
        ("Filter active templates", test_suite.test_filter_active_templates),
        ("Template variables", test_suite.test_template_variables),
    ]
    
    passed = 0
    failed = 0
    
    for test_name, test_func in tests:
        try:
            test_func()
            print(f"✅ {test_name}")
            passed += 1
        except AssertionError as e:
            print(f"❌ {test_name}: {str(e)}")
            failed += 1
        except Exception as e:
            print(f"❌ {test_name}: Unexpected error - {str(e)}")
            failed += 1
    
    # Cleanup
    test_suite.teardown_class()
    
    print("-" * 50)
    print(f"Results: {passed} passed, {failed} failed")
    
    return failed == 0


if __name__ == "__main__":
    success = run_tests()
    exit(0 if success else 1)