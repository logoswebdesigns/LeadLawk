from pydantic import BaseModel
from typing import Optional
from datetime import datetime


class ScrapeRequest(BaseModel):
    industry: str
    location: str
    limit: int = 50
    min_rating: float = 4.0
    min_reviews: int = 3
    recent_days: int = 365
    mock: bool = False
    use_mock_data: bool = False  # Use mock data for testing
    # Browser automation options
    use_browser_automation: bool = True  # Use browser automation (Selenium)
    headless: bool = False  # Run browser in background (False = visible browser)
    use_profile: bool = False  # Use your existing Chrome profile with saved logins
    requires_website: Optional[bool] = None  # Website filter: None = any, False = no website, True = has website
    recent_review_months: Optional[int] = None  # Reviews within X months: None = any, int = within X months
    min_photos: Optional[int] = None  # Minimum photos: None = any, int = minimum photo count
    min_description_length: Optional[int] = None  # Minimum description length: None = any, int = minimum chars


class JobResponse(BaseModel):
    status: str
    processed: int
    total: int
    message: Optional[str] = None


class LeadUpdate(BaseModel):
    status: Optional[str] = None
    notes: Optional[str] = None


class LeadResponse(BaseModel):
    id: str
    business_name: str
    phone: str
    website_url: Optional[str]
    profile_url: Optional[str]
    rating: Optional[float]
    review_count: Optional[int]
    last_review_date: Optional[datetime]
    platform_hint: Optional[str]
    industry: str
    location: str
    source: str
    has_website: bool
    meets_rating_threshold: bool
    has_recent_reviews: bool
    is_candidate: bool
    status: str
    notes: Optional[str]
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True