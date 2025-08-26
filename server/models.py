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
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    call_logs = relationship("CallLog", back_populates="lead", cascade="all, delete-orphan")


class CallLog(Base):
    __tablename__ = "call_logs"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    lead_id = Column(String, ForeignKey("leads.id"), nullable=False)
    called_at = Column(DateTime, default=datetime.utcnow)
    outcome = Column(String, nullable=True)
    notes = Column(Text, nullable=True)
    duration_seconds = Column(Integer, nullable=True)
    
    lead = relationship("Lead", back_populates="call_logs")