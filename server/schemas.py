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