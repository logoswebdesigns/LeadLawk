from sqlalchemy import Column, String, Float, Integer, Boolean, DateTime, Text, ForeignKey, Enum as SQLEnum
from sqlalchemy.orm import relationship
from datetime import datetime, timezone
import enum
import uuid

from database import Base


class LeadStatus(str, enum.Enum):
    new = "new"
    viewed = "viewed"
    called = "called"
    callbackScheduled = "callbackScheduled"
    interested = "interested"
    converted = "converted"
    doNotCall = "doNotCall"
    didNotConvert = "didNotConvert"


class TimelineEntryType(str, enum.Enum):
    LEAD_CREATED = "lead_created"
    STATUS_CHANGE = "status_change"
    NOTE = "note"
    FOLLOW_UP = "follow_up"
    REMINDER = "reminder"
    PHONE_CALL = "phone_call"
    EMAIL = "email"
    MEETING = "meeting"


class Lead(Base):
    __tablename__ = "leads"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    business_name = Column(String, nullable=False, index=True)
    phone = Column(String, nullable=False, index=True)
    website_url = Column(String, nullable=True)
    profile_url = Column(String, nullable=True)
    rating = Column(Float, nullable=True)
    review_count = Column(Integer, nullable=True)
    last_review_date = Column(DateTime, nullable=True)
    platform_hint = Column(String, nullable=True)
    industry = Column(String, nullable=False)
    location = Column(String, nullable=False)
    source = Column(String, nullable=False, default="google_maps")
    has_website = Column(Boolean, default=False)
    meets_rating_threshold = Column(Boolean, default=False)
    has_recent_reviews = Column(Boolean, default=False)
    is_candidate = Column(Boolean, default=False)
    status = Column(SQLEnum(LeadStatus), default=LeadStatus.new)
    notes = Column(Text, nullable=True)
    screenshot_path = Column(String, nullable=True)  # Google Maps business screenshot
    website_screenshot_path = Column(String, nullable=True)  # Website homepage screenshot from PageSpeed
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))
    follow_up_date = Column(DateTime, nullable=True)
    
    # PageSpeed Insights fields
    pagespeed_mobile_score = Column(Integer, nullable=True)
    pagespeed_desktop_score = Column(Integer, nullable=True)
    pagespeed_mobile_performance = Column(Float, nullable=True)
    pagespeed_desktop_performance = Column(Float, nullable=True)
    pagespeed_first_contentful_paint = Column(Float, nullable=True)
    pagespeed_largest_contentful_paint = Column(Float, nullable=True)
    pagespeed_total_blocking_time = Column(Float, nullable=True)
    pagespeed_cumulative_layout_shift = Column(Float, nullable=True)
    pagespeed_speed_index = Column(Float, nullable=True)
    pagespeed_time_to_interactive = Column(Float, nullable=True)
    pagespeed_accessibility_score = Column(Integer, nullable=True)
    pagespeed_best_practices_score = Column(Integer, nullable=True)
    pagespeed_seo_score = Column(Integer, nullable=True)
    pagespeed_tested_at = Column(DateTime, nullable=True)
    pagespeed_test_error = Column(Text, nullable=True)
    
    # Conversion scoring fields
    conversion_score = Column(Float, nullable=True, index=True)  # 0.0 to 1.0 probability
    conversion_score_calculated_at = Column(DateTime, nullable=True)
    conversion_score_factors = Column(Text, nullable=True)  # JSON of contributing factors
    
    # Sales pitch tracking
    sales_pitch_id = Column(String, ForeignKey("sales_pitches.id"), nullable=True)
    
    call_logs = relationship("CallLog", back_populates="lead", cascade="all, delete-orphan")
    timeline_entries = relationship("LeadTimelineEntry", back_populates="lead", cascade="all, delete-orphan", order_by="desc(LeadTimelineEntry.created_at)")
    sales_pitch = relationship("SalesPitch", back_populates="leads")


class CallLog(Base):
    __tablename__ = "call_logs"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    lead_id = Column(String, ForeignKey("leads.id"), nullable=False)
    called_at = Column(DateTime, default=datetime.utcnow)
    outcome = Column(String, nullable=True)
    notes = Column(Text, nullable=True)
    duration_seconds = Column(Integer, nullable=True)
    sales_pitch_id = Column(String, ForeignKey("sales_pitches.id"), nullable=True)
    
    lead = relationship("Lead", back_populates="call_logs")
    sales_pitch = relationship("SalesPitch", back_populates="call_logs")


class LeadTimelineEntry(Base):
    __tablename__ = "lead_timeline_entries"

    id = Column(String, primary_key=True)
    lead_id = Column(String, ForeignKey("leads.id"), nullable=False)
    type = Column(SQLEnum(TimelineEntryType), nullable=False)
    title = Column(String, nullable=False)
    description = Column(Text, nullable=True)
    previous_status = Column(SQLEnum(LeadStatus), nullable=True)
    new_status = Column(SQLEnum(LeadStatus), nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    follow_up_date = Column(DateTime, nullable=True)
    is_completed = Column(Boolean, default=False)
    completed_by = Column(String, nullable=True)
    completed_at = Column(DateTime, nullable=True)
    
    lead = relationship("Lead", back_populates="timeline_entries")


class ConversionModel(Base):
    """Stores the parameters for the conversion scoring model"""
    __tablename__ = "conversion_model"
    
    id = Column(Integer, primary_key=True)
    model_version = Column(String, nullable=False)
    feature_weights = Column(Text, nullable=False)  # JSON of feature weights
    feature_importance = Column(Text, nullable=True)  # JSON of feature importance scores
    model_accuracy = Column(Float, nullable=True)
    training_samples = Column(Integer, nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    is_active = Column(Boolean, default=True)
    
    # Model statistics
    total_conversions = Column(Integer, default=0)
    total_leads = Column(Integer, default=0)
    baseline_conversion_rate = Column(Float, nullable=True)
    
    # Performance metrics
    precision_score = Column(Float, nullable=True)
    recall_score = Column(Float, nullable=True)
    f1_score = Column(Float, nullable=True)


class SalesPitch(Base):
    __tablename__ = "sales_pitches"
    
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    name = Column(String, nullable=False)
    content = Column(Text, nullable=False)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))
    
    # A/B testing metrics
    conversions = Column(Integer, default=0)
    attempts = Column(Integer, default=0)
    conversion_rate = Column(Float, default=0.0)
    
    leads = relationship("Lead", back_populates="sales_pitch")
    call_logs = relationship("CallLog", back_populates="sales_pitch")


class EmailTemplate(Base):
    __tablename__ = "email_templates"
    
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    name = Column(String, nullable=False, unique=True)
    subject = Column(String, nullable=False)
    body = Column(Text, nullable=False)
    description = Column(Text, nullable=True)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))