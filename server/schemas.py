from pydantic import BaseModel, field_serializer, ConfigDict
from typing import Optional, List, Dict, Any
from datetime import datetime, timezone


class BrowserAutomationRequest(BaseModel):
    query: Optional[str] = None  # Full search query (e.g., "electrician papillion")
    industry: str
    industries: Optional[List[str]] = None  # For multi-industry concurrent jobs
    location: str
    locations: Optional[List[str]] = None  # For multi-city searches
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
    enable_pagespeed: bool = False  # Enable automatic PageSpeed testing for leads with websites
    max_pagespeed_score: Optional[int] = None  # Maximum acceptable PageSpeed score (leads above this are filtered out, required if enable_pagespeed is True)
    max_runtime_minutes: Optional[int] = 30  # Maximum runtime in minutes before job auto-stops (default 30 minutes)


class JobResponse(BaseModel):
    status: str
    processed: int
    total: int
    message: Optional[str] = None


class LeadTimelineEntryResponse(BaseModel):
    model_config = ConfigDict(
        from_attributes=True
    )
    
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
        # Helper to ensure datetime is timezone-aware (UTC)
        def ensure_utc(dt):
            if dt and not dt.tzinfo:
                return dt.replace(tzinfo=timezone.utc)
            return dt
            
        return LeadTimelineEntryResponse(
            id=obj.id,
            lead_id=obj.lead_id,
            type=obj.type.value if obj.type else None,
            title=obj.title,
            description=obj.description,
            previous_status=obj.previous_status.value if obj.previous_status else None,
            new_status=obj.new_status.value if obj.new_status else None,
            created_at=ensure_utc(obj.created_at),
            follow_up_date=ensure_utc(obj.follow_up_date),
            is_completed=obj.is_completed,
            completed_by=obj.completed_by,
            completed_at=ensure_utc(obj.completed_at),
        )



class LeadTimelineEntryCreate(BaseModel):
    type: str
    title: str
    description: Optional[str] = None
    previous_status: Optional[str] = None
    new_status: Optional[str] = None
    follow_up_date: Optional[datetime] = None
    is_completed: bool = False
    completed_by: Optional[str] = None
    completed_at: Optional[datetime] = None
    metadata: Optional[Dict[str, Any]] = None


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
    add_to_blacklist: Optional[bool] = False  # Add to blacklist when marking as didNotConvert
    blacklist_reason: Optional[str] = None  # Reason for blacklisting ('too_big', 'franchise', etc.)


class LeadResponse(BaseModel):
    model_config = ConfigDict(
        from_attributes=True
    )
    
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
    website_screenshot_path: Optional[str]
    created_at: datetime
    updated_at: datetime
    follow_up_date: Optional[datetime]
    timeline: List[LeadTimelineEntryResponse] = []
    
    # PageSpeed Insights fields
    pagespeed_mobile_score: Optional[int] = None
    pagespeed_desktop_score: Optional[int] = None
    pagespeed_mobile_performance: Optional[float] = None
    pagespeed_desktop_performance: Optional[float] = None
    pagespeed_first_contentful_paint: Optional[float] = None
    pagespeed_largest_contentful_paint: Optional[float] = None
    pagespeed_total_blocking_time: Optional[float] = None
    pagespeed_cumulative_layout_shift: Optional[float] = None
    pagespeed_speed_index: Optional[float] = None
    pagespeed_time_to_interactive: Optional[float] = None
    pagespeed_accessibility_score: Optional[int] = None
    pagespeed_best_practices_score: Optional[int] = None
    pagespeed_seo_score: Optional[int] = None
    pagespeed_tested_at: Optional[datetime] = None
    pagespeed_test_error: Optional[str] = None
    
    # Conversion scoring fields
    conversion_score: Optional[float] = None
    conversion_score_calculated_at: Optional[datetime] = None
    conversion_score_factors: Optional[str] = None
    
    # Sales pitch tracking
    sales_pitch_id: Optional[str] = None
    sales_pitch_name: Optional[str] = None
    
    # Conversion failure tracking
    conversion_failure_reason: Optional[str] = None
    conversion_failure_notes: Optional[str] = None
    conversion_failure_date: Optional[datetime] = None
    
    @field_serializer('created_at', 'updated_at', 'follow_up_date', 'last_review_date', 'pagespeed_tested_at', 'conversion_score_calculated_at', 'conversion_failure_date')
    def serialize_datetime(self, dt: Optional[datetime]) -> Optional[str]:
        if dt:
            # Ensure timezone-aware and return with Z suffix for UTC
            if not dt.tzinfo:
                dt = dt.replace(tzinfo=timezone.utc)
            return dt.isoformat().replace('+00:00', 'Z')
        return None

    @staticmethod
    def from_orm(obj):
        # Helper to ensure datetime is timezone-aware (UTC)
        def ensure_utc(dt):
            if dt and not dt.tzinfo:
                return dt.replace(tzinfo=timezone.utc)
            return dt
        
        return LeadResponse(
            id=obj.id,
            business_name=obj.business_name,
            phone=obj.phone,
            website_url=obj.website_url,
            profile_url=obj.profile_url,
            rating=obj.rating,
            review_count=obj.review_count,
            last_review_date=ensure_utc(obj.last_review_date),
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
            website_screenshot_path=obj.website_screenshot_path,
            created_at=ensure_utc(obj.created_at),
            updated_at=ensure_utc(obj.updated_at),
            follow_up_date=ensure_utc(obj.follow_up_date),
            timeline=[LeadTimelineEntryResponse.from_orm(entry) for entry in obj.timeline_entries] if hasattr(obj, 'timeline_entries') else [],
            # PageSpeed fields
            pagespeed_mobile_score=obj.pagespeed_mobile_score,
            pagespeed_desktop_score=obj.pagespeed_desktop_score,
            pagespeed_mobile_performance=obj.pagespeed_mobile_performance,
            pagespeed_desktop_performance=obj.pagespeed_desktop_performance,
            pagespeed_first_contentful_paint=obj.pagespeed_first_contentful_paint,
            pagespeed_largest_contentful_paint=obj.pagespeed_largest_contentful_paint,
            pagespeed_total_blocking_time=obj.pagespeed_total_blocking_time,
            pagespeed_cumulative_layout_shift=obj.pagespeed_cumulative_layout_shift,
            pagespeed_speed_index=obj.pagespeed_speed_index,
            pagespeed_time_to_interactive=obj.pagespeed_time_to_interactive,
            pagespeed_accessibility_score=obj.pagespeed_accessibility_score,
            pagespeed_best_practices_score=obj.pagespeed_best_practices_score,
            pagespeed_seo_score=obj.pagespeed_seo_score,
            pagespeed_tested_at=ensure_utc(obj.pagespeed_tested_at),
            pagespeed_test_error=obj.pagespeed_test_error,
            # Conversion scoring fields
            conversion_score=obj.conversion_score,
            conversion_score_calculated_at=ensure_utc(obj.conversion_score_calculated_at),
            conversion_score_factors=obj.conversion_score_factors,
            # Sales pitch tracking
            sales_pitch_id=obj.sales_pitch_id,
            sales_pitch_name=obj.sales_pitch.name if obj.sales_pitch else None,
        )


class LeadStatisticsResponse(BaseModel):
    """Response for overall lead statistics by status"""
    total: int
    by_status: Dict[str, int]
    conversion_rate: float
    
    class Config:
        protected_namespaces = ()


class ConversionModelResponse(BaseModel):
    """Response for conversion model information"""
    model_version: str
    accuracy: Optional[float]
    f1_score: Optional[float]
    precision: Optional[float]
    recall: Optional[float]
    training_samples: Optional[int]
    baseline_conversion_rate: Optional[float]
    created_at: Optional[datetime]
    is_active: bool
    
    class Config:
        protected_namespaces = ()


class ConversionScoringResponse(BaseModel):
    """Response for conversion scoring operations"""
    status: str
    total_leads: Optional[int] = None
    scores_updated: Optional[int] = None
    duration_seconds: Optional[float] = None
    average_time_per_lead: Optional[float] = None
    message: Optional[str] = None
    errors: List[str] = []
    stats: Optional[dict] = None
    
    class Config:
        protected_namespaces = ()


class SalesPitchBase(BaseModel):
    name: str
    content: str
    is_active: bool = True


class SalesPitchCreate(SalesPitchBase):
    pass


class SalesPitchUpdate(BaseModel):
    name: Optional[str] = None
    content: Optional[str] = None
    is_active: Optional[bool] = None


class SalesPitchResponse(SalesPitchBase):
    id: str
    created_at: datetime
    updated_at: datetime
    conversions: int
    attempts: int
    conversion_rate: float
    


class EmailTemplateBase(BaseModel):
    name: str
    subject: str
    body: str
    description: Optional[str] = None
    is_active: bool = True


class EmailTemplateCreate(EmailTemplateBase):
    pass


class EmailTemplateUpdate(BaseModel):
    name: Optional[str] = None
    subject: Optional[str] = None
    body: Optional[str] = None
    description: Optional[str] = None
    is_active: Optional[bool] = None


class PaginatedResponse(BaseModel):
    """Generic paginated response wrapper"""
    items: List[Any]
    total: int
    page: int
    per_page: int
    total_pages: int
    has_next: bool
    has_prev: bool
    


class EmailTemplateResponse(BaseModel):
    id: str
    name: str
    subject: str
    body: str
    description: Optional[str]
    is_active: bool
    created_at: datetime
    updated_at: datetime
    


class LeadUpdateRequest(BaseModel):
    status: Optional[str] = None
    notes: Optional[str] = None
    sales_pitch_id: Optional[str] = None
    follow_up_date: Optional[datetime] = None
    conversion_failure_reason: Optional[str] = None
    conversion_failure_notes: Optional[str] = None
    conversion_failure_date: Optional[datetime] = None
