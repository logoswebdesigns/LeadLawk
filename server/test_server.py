import pytest
from fastapi.testclient import TestClient
from main import app
from database import SessionLocal, init_db
from models import Lead, LeadStatus
import json

client = TestClient(app)


def setup_module(module):
    init_db()


def test_scrape_job_with_thresholds():
    response = client.post("/jobs/scrape", json={
        "industry": "painter",
        "location": "Austin, TX",
        "limit": 5,
        "min_rating": 4.5,
        "min_reviews": 5,
        "recent_days": 180
    })
    
    assert response.status_code == 200
    data = response.json()
    assert "job_id" in data
    
    job_id = data["job_id"]
    
    import time
    time.sleep(2)
    
    job_response = client.get(f"/jobs/{job_id}")
    assert job_response.status_code == 200
    job_data = job_response.json()
    assert job_data["status"] in ["running", "done"]


def test_get_leads_filtering():
    db = SessionLocal()
    
    lead1 = Lead(
        business_name="Test Painter 1",
        phone="555-0001",
        industry="painter",
        location="Austin, TX",
        is_candidate=True,
        status=LeadStatus.NEW
    )
    lead2 = Lead(
        business_name="Test Painter 2",
        phone="555-0002",
        industry="painter",
        location="Austin, TX",
        is_candidate=False,
        status=LeadStatus.CALLED
    )
    
    db.add(lead1)
    db.add(lead2)
    db.commit()
    db.close()
    
    response = client.get("/leads?candidates_only=true")
    assert response.status_code == 200
    leads = response.json()
    assert all(lead["is_candidate"] for lead in leads)
    
    response = client.get("/leads?status=called")
    assert response.status_code == 200
    leads = response.json()
    assert all(lead["status"] == "called" for lead in leads)


def test_update_lead():
    db = SessionLocal()
    lead = Lead(
        business_name="Test Business",
        phone="555-1234",
        industry="painter",
        location="Austin, TX",
        status=LeadStatus.NEW
    )
    db.add(lead)
    db.commit()
    lead_id = lead.id
    db.close()
    
    response = client.put(f"/leads/{lead_id}", json={
        "status": "called",
        "notes": "Left voicemail"
    })
    
    assert response.status_code == 200
    updated_lead = response.json()
    assert updated_lead["status"] == "called"
    assert updated_lead["notes"] == "Left voicemail"


def test_threshold_calculation():
    from scraper.gmaps_spider import GMapsSpider
    from datetime import datetime, timedelta
    
    spider = GMapsSpider(
        min_rating=4.5,
        min_reviews=10,
        recent_days=180
    )
    
    recent_date = datetime.utcnow() - timedelta(days=90)
    old_date = datetime.utcnow() - timedelta(days=365)
    
    lead_data = {
        'rating': 4.6,
        'review_count': 15,
        'last_review_date': recent_date
    }
    
    meets_rating = lead_data['rating'] >= spider.min_rating
    has_enough_reviews = lead_data['review_count'] >= spider.min_reviews
    recent_cutoff = datetime.utcnow() - timedelta(days=spider.recent_days)
    has_recent = lead_data['last_review_date'] >= recent_cutoff
    
    assert meets_rating == True
    assert has_enough_reviews == True
    assert has_recent == True
    
    is_candidate = meets_rating and has_enough_reviews and has_recent
    assert is_candidate == True
    
    lead_data['rating'] = 4.0
    meets_rating = lead_data['rating'] >= spider.min_rating
    is_candidate = meets_rating and has_enough_reviews and has_recent
    assert is_candidate == False


if __name__ == "__main__":
    pytest.main([__file__])