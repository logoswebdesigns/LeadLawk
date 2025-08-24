import scrapy
from datetime import datetime, timedelta
import re
import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from database import SessionLocal
from models import Lead, LeadStatus

# Try to import the real scraper; do NOT fallback to mock unless explicitly requested
try:
    from scraper.gmaps_scraper import GoogleMapsScraper
    REAL_SCRAPER_AVAILABLE = True
except ImportError:
    REAL_SCRAPER_AVAILABLE = False
    print("Selenium/driver not available. Real scraper disabled.")


class GMapsSpider(scrapy.Spider):
    name = 'gmaps'
    
    def __init__(self, industry='', location='', limit=50, min_rating=4.0, 
                 min_reviews=3, recent_days=365, job_id=None, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.industry = industry
        self.location = location
        self.limit = int(limit)
        self.min_rating = float(min_rating)
        self.min_reviews = int(min_reviews)
        self.recent_days = int(recent_days)
        self.job_id = job_id
        self.processed_count = 0
        
        query = f"{industry} {location}".replace(' ', '+')
        self.start_urls = [
            f'https://www.google.com/maps/search/{query}'
        ]
    
    def parse(self, response):
        self.logger.info(f"Scraping for {self.industry} in {self.location}")
        
        use_mock = os.environ.get('USE_MOCK_DATA') == 'true'
        # Use real scraper only when available and mock is not explicitly requested
        if REAL_SCRAPER_AVAILABLE and not use_mock:
            try:
                self.logger.info("Using real Google Maps scraper")
                scraper = GoogleMapsScraper(headless=True, job_id=self.job_id)
                results = scraper.scrape(
                    self.industry, 
                    self.location, 
                    self.limit,
                    self.min_rating,
                    self.min_reviews
                )
                self.logger.info(f"Real scraper found {len(results)} businesses")
                for result in results:
                    self.processed_count += 1
                    if self.job_id:
                        self.update_job_progress()
                    yield {}
            except Exception as e:
                self.logger.error(f"Real scraper failed: {e}")
                return
        elif use_mock:
            self.logger.warning("USE_MOCK_DATA enabled: generating mock leads")
            for i in range(min(self.limit, 20)):
                yield self.create_mock_lead(i)
        else:
            self.logger.error("Real scraper not available. Install selenium and chromedriver, or set USE_MOCK_DATA=true to use mock data.")
            return
    
    def create_mock_lead(self, index):
        mock_businesses = [
            {"name": "Pro Painters LLC", "phone": "(512) 555-0101", "rating": 4.8, "reviews": 127},
            {"name": "Austin Elite Painting", "phone": "(512) 555-0102", "rating": 4.5, "reviews": 89},
            {"name": "Color Masters", "phone": "(512) 555-0103", "rating": 4.2, "reviews": 45},
            {"name": "Premium Paint Co", "phone": "(512) 555-0104", "rating": 4.9, "reviews": 203},
            {"name": "Quick Brush Services", "phone": "(512) 555-0105", "rating": 3.8, "reviews": 12},
            {"name": "Landscape Pros", "phone": "(512) 555-0201", "rating": 4.6, "reviews": 156},
            {"name": "Green Thumb Gardens", "phone": "(512) 555-0202", "rating": 4.4, "reviews": 78},
            {"name": "Yard Masters", "phone": "(512) 555-0203", "rating": 4.7, "reviews": 92},
            {"name": "Elite Roofing", "phone": "(512) 555-0301", "rating": 4.5, "reviews": 234},
            {"name": "Top Tier Roofs", "phone": "(512) 555-0302", "rating": 4.3, "reviews": 67},
            {"name": "Expert Plumbing", "phone": "(512) 555-0401", "rating": 4.8, "reviews": 189},
            {"name": "Flow Masters", "phone": "(512) 555-0402", "rating": 4.1, "reviews": 34},
            {"name": "Spark Electric", "phone": "(512) 555-0501", "rating": 4.9, "reviews": 312},
            {"name": "Power Pro Electric", "phone": "(512) 555-0502", "rating": 4.6, "reviews": 145},
            {"name": "Bright Wire Services", "phone": "(512) 555-0503", "rating": 4.2, "reviews": 28},
            {"name": "Custom Contractors", "phone": "(512) 555-0601", "rating": 4.7, "reviews": 198},
            {"name": "Build Right Co", "phone": "(512) 555-0602", "rating": 4.4, "reviews": 76},
            {"name": "Home Improvements Plus", "phone": "(512) 555-0603", "rating": 4.5, "reviews": 109},
            {"name": "Quality Services", "phone": "(512) 555-0604", "rating": 4.3, "reviews": 52},
            {"name": "Professional Team", "phone": "(512) 555-0605", "rating": 4.8, "reviews": 167},
        ]
        
        business = mock_businesses[index % len(mock_businesses)]
        
        has_website = index % 3 != 0
        website_url = None
        platform_hint = None
        
        if has_website:
            if index % 5 == 0:
                website_url = f"{business['name'].lower().replace(' ', '')}.business.site"
                platform_hint = "business.site"
            elif index % 7 == 0:
                website_url = f"{business['name'].lower().replace(' ', '')}.godaddysites.com"
                platform_hint = "godaddysites"
            else:
                website_url = f"www.{business['name'].lower().replace(' ', '')}.com"
        
        last_review_date = datetime.utcnow() - timedelta(days=(index * 30))
        recent_cutoff = datetime.utcnow() - timedelta(days=self.recent_days)
        
        meets_rating = business['rating'] >= self.min_rating
        has_enough_reviews = business['reviews'] >= self.min_reviews
        has_recent = last_review_date >= recent_cutoff
        is_candidate = meets_rating and has_enough_reviews and has_recent
        
        self.processed_count += 1
        self.save_to_db({
            'business_name': business['name'],
            'phone': business['phone'],
            'website_url': website_url,
            'profile_url': f"https://maps.google.com/business/{business['name'].lower().replace(' ', '')}",
            'rating': business['rating'],
            'review_count': business['reviews'],
            'last_review_date': last_review_date,
            'platform_hint': platform_hint,
            'industry': self.industry,
            'location': self.location,
            'source': 'google_maps',
            'has_website': has_website,
            'meets_rating_threshold': meets_rating,
            'has_recent_reviews': has_recent,
            'is_candidate': is_candidate,
        })
        
        if self.job_id:
            self.update_job_progress()
        
        return {}
    
    def save_to_db(self, item):
        db = SessionLocal()
        try:
            existing = db.query(Lead).filter(
                Lead.business_name == item['business_name'],
                Lead.phone == item['phone']
            ).first()
            
            if existing:
                for key, value in item.items():
                    setattr(existing, key, value)
                existing.updated_at = datetime.utcnow()
            else:
                lead = Lead(**item)
                db.add(lead)
            
            db.commit()
        finally:
            db.close()
    
    def update_job_progress(self):
        if self.job_id:
            import sys
            sys.path.append('..')
            from main import update_job_status
            update_job_status(self.job_id, "running", self.processed_count, self.limit)
