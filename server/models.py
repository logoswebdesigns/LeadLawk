from sqlalchemy import Column, String, Float, Integer, Boolean, DateTime, Text, ForeignKey, Enum as SQLEnum
from sqlalchemy.orm import relationship
from datetime import datetime
import enum
import uuid

from database import Base


class LeadStatus(str, enum.Enum):
    NEW = "new"
    VIEWED = "viewed"
    CALLED = "called"
    INTERESTED = "interested"
    CONVERTED = "converted"
    DNC = "dnc"


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
    status = Column(SQLEnum(LeadStatus), default=LeadStatus.NEW)
    notes = Column(Text, nullable=True)
    screenshot_path = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    follow_up_date = Column(DateTime, nullable=True)
    
    call_logs = relationship("CallLog", back_populates="lead", cascade="all, delete-orphan")
    timeline_entries = relationship("LeadTimelineEntry", back_populates="lead", cascade="all, delete-orphan", order_by="desc(LeadTimelineEntry.created_at)")


class CallLog(Base):
    __tablename__ = "call_logs"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    lead_id = Column(String, ForeignKey("leads.id"), nullable=False)
    called_at = Column(DateTime, default=datetime.utcnow)
    outcome = Column(String, nullable=True)
    notes = Column(Text, nullable=True)
    duration_seconds = Column(Integer, nullable=True)
    
    lead = relationship("Lead", back_populates="call_logs")


class LeadTimelineEntry(Base):
    __tablename__ = "lead_timeline_entries"

    id = Column(String, primary_key=True)
    lead_id = Column(String, ForeignKey("leads.id"), nullable=False)
    type = Column(SQLEnum(TimelineEntryType), nullable=False)
    title = Column(String, nullable=False)
    description = Column(Text, nullable=True)
    previous_status = Column(SQLEnum(LeadStatus), nullable=True)
    new_status = Column(SQLEnum(LeadStatus), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    follow_up_date = Column(DateTime, nullable=True)
    is_completed = Column(Boolean, default=False)
    completed_by = Column(String, nullable=True)
    completed_at = Column(DateTime, nullable=True)
    
    lead = relationship("Lead", back_populates="timeline_entries")