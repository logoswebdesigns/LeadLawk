from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime


class ScrapeRequest(BaseModel):
    industry: str
    industries: Optional[List[str]] = None  # For multi-industry concurrent jobs
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


class LeadTimelineEntryResponse(BaseModel):
    id: str
    lead_id: str
    type: str
    title: str
    description: Optional[str]
    previous_status: Optional[str]
    new_status: Optional[str]
    created_at: datetime
    follow_up_date: Optional[datetime]
    is_completed: bool
    completed_by: Optional[str]
    completed_at: Optional[datetime]

    @staticmethod
    def from_orm(obj):
        return LeadTimelineEntryResponse(
            id=obj.id,
            lead_id=obj.lead_id,
            type=obj.type.value if obj.type else None,
            title=obj.title,
            description=obj.description,
            previous_status=obj.previous_status.value if obj.previous_status else None,
            new_status=obj.new_status.value if obj.new_status else None,
            created_at=obj.created_at,
            follow_up_date=obj.follow_up_date,
            is_completed=obj.is_completed,
            completed_by=obj.completed_by,
            completed_at=obj.completed_at,
        )

    class Config:
        from_attributes = True


class LeadTimelineEntryCreate(BaseModel):
    id: str
    type: str
    title: str
    description: Optional[str] = None
    previous_status: Optional[str] = None
    new_status: Optional[str] = None
    follow_up_date: Optional[datetime] = None
    is_completed: bool = False
    completed_by: Optional[str] = None
    completed_at: Optional[datetime] = None


class LeadTimelineEntryUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    follow_up_date: Optional[datetime] = None
    is_completed: Optional[bool] = None
    completed_by: Optional[str] = None
    completed_at: Optional[datetime] = None


class LeadUpdate(BaseModel):
    status: Optional[str] = None
    notes: Optional[str] = None
    follow_up_date: Optional[datetime] = None
    timeline: Optional[List[LeadTimelineEntryCreate]] = None


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
    screenshot_path: Optional[str]
    created_at: datetime
    updated_at: datetime
    follow_up_date: Optional[datetime]
    timeline: List[LeadTimelineEntryResponse] = []

    @staticmethod
    def from_orm(obj):
        return LeadResponse(
            id=obj.id,
            business_name=obj.business_name,
            phone=obj.phone,
            website_url=obj.website_url,
            profile_url=obj.profile_url,
            rating=obj.rating,
            review_count=obj.review_count,
            last_review_date=obj.last_review_date,
            platform_hint=obj.platform_hint,
            industry=obj.industry,
            location=obj.location,
            source=obj.source,
            has_website=obj.has_website,
            meets_rating_threshold=obj.meets_rating_threshold,
            has_recent_reviews=obj.has_recent_reviews,
            is_candidate=obj.is_candidate,
            status=obj.status.value if hasattr(obj.status, 'value') else obj.status,
            notes=obj.notes,
            screenshot_path=obj.screenshot_path,
            created_at=obj.created_at,
            updated_at=obj.updated_at,
            follow_up_date=obj.follow_up_date,
            timeline=[LeadTimelineEntryResponse.from_orm(entry) for entry in obj.timeline_entries] if hasattr(obj, 'timeline_entries') else []
        )

    class Config:
        from_attributes = True