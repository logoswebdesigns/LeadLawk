#!/usr/bin/env python3
"""
Lead management operations and CRUD
"""

from typing import List, Optional
from datetime import datetime
from sqlalchemy.orm import selectinload
from database import SessionLocal
from models import Lead, LeadStatus, LeadTimelineEntry
from schemas import LeadResponse, LeadUpdate, LeadTimelineEntryUpdate


def get_all_leads() -> List[Lead]:
    """Get all leads from database with timeline entries"""
    try:
        db = SessionLocal()
        leads = db.query(Lead).options(
            selectinload(Lead.timeline_entries)
        ).order_by(Lead.created_at.desc()).all()
        db.close()
        return leads
    except Exception as e:
        print(f"Error getting leads: {e}")
        return []


def get_lead_by_id(lead_id: str) -> Optional[Lead]:
    """Get a specific lead by ID with timeline entries and sales pitch"""
    try:
        db = SessionLocal()
        lead = db.query(Lead).options(
            selectinload(Lead.timeline_entries),
            selectinload(Lead.sales_pitch)
        ).filter(Lead.id == lead_id).first()
        db.close()
        return lead
    except Exception as e:
        print(f"Error getting lead {lead_id}: {e}")
        return None


def delete_lead_by_id(lead_id: str) -> bool:
    """Delete a specific lead by ID"""
    import os
    from pathlib import Path
    
    try:
        db = SessionLocal()
        lead = db.query(Lead).filter(Lead.id == lead_id).first()
        
        if not lead:
            db.close()
            return False
        
        # Delete associated screenshot files
        if lead.screenshot_path:
            screenshot_file = Path("screenshots") / lead.screenshot_path
            if screenshot_file.exists():
                try:
                    os.remove(screenshot_file)
                    print(f"🗑️ Deleted Google Maps screenshot: {lead.screenshot_path}")
                except Exception as e:
                    print(f"⚠️ Failed to delete Google Maps screenshot: {e}")
        
        # Delete website screenshot if it exists
        if lead.website_screenshot_path:
            website_screenshot_file = Path("website_screenshots") / lead.website_screenshot_path
            if website_screenshot_file.exists():
                try:
                    os.remove(website_screenshot_file)
                    print(f"🗑️ Deleted website screenshot: {lead.website_screenshot_path}")
                except Exception as e:
                    print(f"⚠️ Failed to delete website screenshot: {e}")
        
        db.delete(lead)
        db.commit()
        db.close()
        return True
        
    except Exception as e:
        print(f"Error deleting lead {lead_id}: {e}")
        return False


def delete_all_leads() -> bool:
    """Delete all leads from database"""
    import os
    from pathlib import Path
    
    try:
        db = SessionLocal()
        
        # Get all leads to delete their screenshots
        all_leads = db.query(Lead).all()
        
        # Delete screenshots for each lead
        for lead in all_leads:
            # Delete Google Maps screenshot
            if lead.screenshot_path:
                screenshot_file = Path("screenshots") / lead.screenshot_path
                if screenshot_file.exists():
                    try:
                        os.remove(screenshot_file)
                        print(f"🗑️ Deleted Google Maps screenshot: {lead.screenshot_path}")
                    except Exception as e:
                        print(f"⚠️ Failed to delete Google Maps screenshot: {e}")
            
            # Delete website screenshot
            if lead.website_screenshot_path:
                website_screenshot_file = Path("website_screenshots") / lead.website_screenshot_path
                if website_screenshot_file.exists():
                    try:
                        os.remove(website_screenshot_file)
                        print(f"🗑️ Deleted website screenshot: {lead.website_screenshot_path}")
                    except Exception as e:
                        print(f"⚠️ Failed to delete website screenshot: {e}")
        
        # Delete all timeline entries first (due to foreign key constraints)
        db.query(LeadTimelineEntry).delete()
        
        # Then delete all leads
        deleted_count = db.query(Lead).delete()
        db.commit()
        
        print(f"Deleted {deleted_count} leads and their associated screenshots")
        db.close()
        return True
        
    except Exception as e:
        print(f"Error deleting all leads: {e}")
        return False


def delete_mock_leads() -> bool:
    """Delete leads with 'Mock' in the name"""
    import os
    from pathlib import Path
    
    try:
        db = SessionLocal()
        
        # Find mock leads
        mock_leads = db.query(Lead).filter(Lead.business_name.ilike('%Mock%')).all()
        mock_lead_ids = [lead.id for lead in mock_leads]
        
        # Delete screenshots for each mock lead
        for lead in mock_leads:
            # Delete Google Maps screenshot
            if lead.screenshot_path:
                screenshot_file = Path("screenshots") / lead.screenshot_path
                if screenshot_file.exists():
                    try:
                        os.remove(screenshot_file)
                        print(f"🗑️ Deleted Google Maps screenshot: {lead.screenshot_path}")
                    except Exception as e:
                        print(f"⚠️ Failed to delete Google Maps screenshot: {e}")
            
            # Delete website screenshot
            if lead.website_screenshot_path:
                website_screenshot_file = Path("website_screenshots") / lead.website_screenshot_path
                if website_screenshot_file.exists():
                    try:
                        os.remove(website_screenshot_file)
                        print(f"🗑️ Deleted website screenshot: {lead.website_screenshot_path}")
                    except Exception as e:
                        print(f"⚠️ Failed to delete website screenshot: {e}")
        
        # Delete timeline entries for mock leads
        if mock_lead_ids:
            db.query(LeadTimelineEntry).filter(LeadTimelineEntry.lead_id.in_(mock_lead_ids)).delete()
        
        # Delete mock leads
        deleted_count = db.query(Lead).filter(Lead.business_name.ilike('%Mock%')).delete()
        db.commit()
        
        print(f"Deleted {deleted_count} mock leads and their associated screenshots")
        db.close()
        return True
        
    except Exception as e:
        print(f"Error deleting mock leads: {e}")
        return False


def update_lead(lead_id: str, update_data: LeadUpdate) -> Optional[Lead]:
    """Update a lead with new data"""
    try:
        db = SessionLocal()
        lead = db.query(Lead).options(
            selectinload(Lead.timeline_entries)
        ).filter(Lead.id == lead_id).first()
        
        if not lead:
            db.close()
            return None
        
        # Update fields if provided
        update_dict = update_data.dict(exclude_unset=True)
        for field, value in update_dict.items():
            if hasattr(lead, field):
                setattr(lead, field, value)
        
        lead.updated_at = datetime.utcnow()
        db.commit()
        db.refresh(lead)
        db.close()
        
        return lead
        
    except Exception as e:
        print(f"Error updating lead {lead_id}: {e}")
        return None


def update_lead_timeline_entry(lead_id: str, entry_id: str, update_data: LeadTimelineEntryUpdate) -> Optional[Lead]:
    """Update a specific timeline entry for a lead"""
    try:
        db = SessionLocal()
        lead = db.query(Lead).options(
            selectinload(Lead.timeline_entries)
        ).filter(Lead.id == lead_id).first()
        
        if not lead:
            db.close()
            return None
        
        # Find the timeline entry
        entry = db.query(LeadTimelineEntry).filter(
            LeadTimelineEntry.id == entry_id,
            LeadTimelineEntry.lead_id == lead_id
        ).first()
        
        if not entry:
            db.close()
            return None
        
        # Update the entry
        update_dict = update_data.dict(exclude_unset=True)
        for field, value in update_dict.items():
            if hasattr(entry, field):
                setattr(entry, field, value)
        
        entry.updated_at = datetime.utcnow()
        db.commit()
        db.refresh(lead)
        db.close()
        
        return lead
        
    except Exception as e:
        print(f"Error updating timeline entry {entry_id} for lead {lead_id}: {e}")
        return None


def search_leads(query: Optional[str] = None, status: Optional[str] = None) -> List[Lead]:
    """Search leads by query and/or status"""
    try:
        db = SessionLocal()
        lead_query = db.query(Lead)
        
        # Filter by search query if provided
        if query:
            lead_query = lead_query.filter(
                Lead.business_name.ilike(f'%{query}%') |
                Lead.phone.ilike(f'%{query}%') |
                Lead.location.ilike(f'%{query}%')
            )
        
        # Filter by status if provided
        if status and status != "all":
            try:
                status_enum = LeadStatus(status)
                lead_query = lead_query.filter(Lead.status == status_enum)
            except ValueError:
                pass  # Invalid status, ignore filter
        
        leads = lead_query.order_by(Lead.created_at.desc()).all()
        db.close()
        return leads
        
    except Exception as e:
        print(f"Error searching leads: {e}")
        return []


def get_leads_stats() -> dict:
    """Get lead statistics"""
    try:
        db = SessionLocal()
        total_leads = db.query(Lead).count()
        
        # Count by status
        stats = {"total": total_leads}
        for status in LeadStatus:
            count = db.query(Lead).filter(Lead.status == status).count()
            stats[status.value] = count
        
        db.close()
        return stats
        
    except Exception as e:
        print(f"Error getting lead stats: {e}")
        return {"total": 0}