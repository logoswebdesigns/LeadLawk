"""
Compliant Lead Fetcher
Uses legitimate APIs through the maps proxy service to find business leads
"""

import asyncio
import httpx
from typing import List, Dict, Any, Optional
from datetime import datetime
import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from database import SessionLocal
from models import Lead, LeadStatus

class LeadFetcher:
    """Fetches business leads using compliant API methods"""
    
    def __init__(self, maps_proxy_url: str = "http://localhost:8001"):
        self.maps_proxy_url = maps_proxy_url
        self.session = None
    
    async def fetch_leads(self, 
                         industry: str, 
                         location: str, 
                         limit: int = 50,
                         min_rating: float = 4.0,
                         min_reviews: int = 10) -> List[Dict[str, Any]]:
        """
        Fetch business leads from legitimate sources
        """
        leads = []
        
        async with httpx.AsyncClient(timeout=30.0) as client:
            # Search for businesses using the maps proxy
            search_query = f"{industry} in {location}"
            
            try:
                response = await client.post(
                    f"{self.maps_proxy_url}/search/places",
                    json={
                        "query": search_query,
                        "location": location,
                        "limit": limit
                        # Provider will be auto-selected based on availability
                    }
                )
                
                if response.status_code == 200:
                    data = response.json()
                    places = data.get("places", [])
                    
                    for place in places:
                        # Filter based on criteria if data is available
                        rating = place.get("rating")
                        review_count = place.get("review_count")
                        
                        # If no rating/review data, include the lead (common with OSM data)
                        # Otherwise, apply filters
                        if (rating is None and review_count is None) or \
                           (rating is not None and rating >= min_rating) or \
                           (review_count is not None and review_count >= min_reviews):
                            lead = {
                                "business_name": place.get("name"),
                                "phone": place.get("phone"),
                                "website_url": place.get("website"),
                                "address": place.get("address"),
                                "rating": rating if rating is not None else 0,
                                "review_count": review_count if review_count is not None else 0,
                                "location": location,
                                "industry": industry,
                                "source": f"api_{place.get('source', 'unknown')}",
                                "has_website": bool(place.get("website")),
                                "is_candidate": not bool(place.get("website")),
                                "latitude": place.get("location", {}).get("lat"),
                                "longitude": place.get("location", {}).get("lng"),
                                "place_url": place.get("place_url"),
                                "raw_data": place.get("raw_data")
                            }
                            leads.append(lead)
                            
                            # Save to database
                            self._save_lead(lead)
                
            except Exception as e:
                print(f"Error fetching leads: {e}")
        
        return leads
    
    def _save_lead(self, lead_data: Dict[str, Any]):
        """Save lead to database"""
        db = SessionLocal()
        try:
            # Check if lead already exists
            existing = db.query(Lead).filter(
                Lead.business_name == lead_data["business_name"],
                Lead.phone == lead_data.get("phone")
            ).first()
            
            if not existing:
                lead = Lead(
                    business_name=lead_data["business_name"],
                    phone=lead_data.get("phone") or "",
                    website_url=lead_data.get("website_url"),
                    profile_url=lead_data.get("place_url"),
                    rating=lead_data.get("rating"),
                    review_count=lead_data.get("review_count"),
                    location=lead_data["location"],
                    industry=lead_data["industry"],
                    source=lead_data["source"],
                    status=LeadStatus.NEW,
                    has_website=lead_data.get("has_website", False),
                    is_candidate=lead_data.get("is_candidate", False),
                    meets_rating_threshold=lead_data.get("rating", 0) >= 4.0,
                    has_recent_reviews=True,  # Assume true for API results
                    created_at=datetime.utcnow(),
                    updated_at=datetime.utcnow()
                )
                db.add(lead)
                db.commit()
        finally:
            db.close()

async def run_lead_fetch(industry: str, location: str, limit: int = 50, 
                        min_rating: float = 4.0, min_reviews: int = 10,
                        job_id: Optional[str] = None):
    """Run the lead fetching process"""
    fetcher = LeadFetcher()
    
    # If running as part of a job, update status
    if job_id:
        from main import add_job_log, update_job_status
        add_job_log(job_id, f"Starting compliant lead fetch for {industry} in {location}")
    
    try:
        leads = await fetcher.fetch_leads(
            industry=industry,
            location=location,
            limit=limit,
            min_rating=min_rating,
            min_reviews=min_reviews
        )
        
        if job_id:
            add_job_log(job_id, f"Successfully fetched {len(leads)} leads from APIs")
            update_job_status(job_id, "done", len(leads), limit)
        
        return leads
        
    except Exception as e:
        if job_id:
            add_job_log(job_id, f"Error: {str(e)}")
            update_job_status(job_id, "error", 0, limit, str(e))
        raise

if __name__ == "__main__":
    # Test the fetcher
    import sys
    if len(sys.argv) > 2:
        industry = sys.argv[1]
        location = sys.argv[2]
        asyncio.run(run_lead_fetch(industry, location))
    else:
        print("Usage: python lead_fetcher.py <industry> <location>")
        print("Example: python lead_fetcher.py 'coffee shops' 'Seattle, WA'")