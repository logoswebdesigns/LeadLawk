#!/usr/bin/env python3
"""
Excel export functionality for leads with full data and timeline
Using xlsxwriter for reliable Excel generation
"""

import io
from datetime import datetime
from typing import Optional
from sqlalchemy.orm import Session
import xlsxwriter

from models import Lead, LeadTimelineEntry, CallLog
from database import SessionLocal


def export_leads_to_excel(
    status: Optional[str] = None,
    industry: Optional[str] = None,
    location: Optional[str] = None,
    search_query: Optional[str] = None,
    has_website: Optional[bool] = None,
    min_rating: Optional[float] = None,
    min_reviews: Optional[int] = None,
    min_pagespeed_mobile: Optional[int] = None,
    max_pagespeed_mobile: Optional[int] = None,
    min_pagespeed_desktop: Optional[int] = None,
    max_pagespeed_desktop: Optional[int] = None,
    pagespeed_tested: Optional[bool] = None
) -> bytes:
    """
    Export filtered leads to Excel with all associated data.
    Returns Excel file as bytes for download.
    """
    db = SessionLocal()
    output = io.BytesIO()
    
    try:
        # Create workbook with xlsxwriter
        workbook = xlsxwriter.Workbook(output, {'in_memory': True})
        
        # Define formats
        header_format = workbook.add_format({
            'bold': True,
            'bg_color': '#366092',
            'font_color': 'white',
            'border': 1,
            'align': 'center',
            'valign': 'vcenter'
        })
        
        # Status color formats
        status_formats = {
            'NEW': workbook.add_format({'bg_color': '#E8F5E9', 'border': 1}),
            'CONTACTED': workbook.add_format({'bg_color': '#FFF3E0', 'border': 1}),
            'INTERESTED': workbook.add_format({'bg_color': '#E3F2FD', 'border': 1}),
            'CONVERTED': workbook.add_format({'bg_color': '#C8E6C9', 'border': 1}),
            'DNC': workbook.add_format({'bg_color': '#FFEBEE', 'border': 1}),
        }
        
        border_format = workbook.add_format({'border': 1})
        date_format = workbook.add_format({'border': 1, 'num_format': 'yyyy-mm-dd hh:mm'})
        
        # Build query with filters
        query = db.query(Lead)
        
        # Apply filters matching the API logic
        if status:
            query = query.filter(Lead.status == status)
        if industry:
            query = query.filter(Lead.industry.ilike(f"%{industry}%"))
        if location:
            query = query.filter(Lead.location.ilike(f"%{location}%"))
        if search_query:
            query = query.filter(
                (Lead.business_name.ilike(f"%{search_query}%")) |
                (Lead.location.ilike(f"%{search_query}%")) |
                (Lead.industry.ilike(f"%{search_query}%"))
            )
        if has_website is not None:
            if has_website:
                query = query.filter(Lead.website_url.isnot(None))
            else:
                query = query.filter(Lead.website_url.is_(None))
        if min_rating:
            query = query.filter(Lead.rating >= min_rating)
        if min_reviews:
            query = query.filter(Lead.review_count >= min_reviews)
        
        # PageSpeed filters
        if min_pagespeed_mobile is not None:
            query = query.filter(Lead.pagespeed_mobile_score >= min_pagespeed_mobile)
        if max_pagespeed_mobile is not None:
            query = query.filter(Lead.pagespeed_mobile_score <= max_pagespeed_mobile)
        if min_pagespeed_desktop is not None:
            query = query.filter(Lead.pagespeed_desktop_score >= min_pagespeed_desktop)
        if max_pagespeed_desktop is not None:
            query = query.filter(Lead.pagespeed_desktop_score <= max_pagespeed_desktop)
        if pagespeed_tested is not None:
            if pagespeed_tested:
                query = query.filter(Lead.pagespeed_tested_at.isnot(None))
            else:
                query = query.filter(Lead.pagespeed_tested_at.is_(None))
        
        # Get filtered leads
        leads = query.order_by(Lead.created_at.desc()).all()
        
        # Create Summary Sheet
        summary_sheet = workbook.add_worksheet('Summary')
        summary_sheet.write(0, 0, 'Lead Export Summary', workbook.add_format({'bold': True, 'size': 14}))
        summary_sheet.write(2, 0, 'Generated:')
        summary_sheet.write(2, 1, datetime.now().strftime('%Y-%m-%d %H:%M'))
        summary_sheet.write(4, 0, 'Total Leads:')
        summary_sheet.write(4, 1, len(leads))
        
        # Status breakdown
        row = 6
        summary_sheet.write(row, 0, 'Status Breakdown:', workbook.add_format({'bold': True}))
        status_counts = {}
        for lead in leads:
            status_counts[lead.status] = status_counts.get(lead.status, 0) + 1
        
        for status_name, count in status_counts.items():
            row += 1
            percentage = (count / len(leads) * 100) if leads else 0
            summary_sheet.write(row, 0, f'  {status_name}:')
            summary_sheet.write(row, 1, f'{count} ({percentage:.1f}%)')
        
        # Website status
        row += 2
        with_website = sum(1 for lead in leads if lead.website_url)
        without_website = len(leads) - with_website
        summary_sheet.write(row, 0, 'Website Status:', workbook.add_format({'bold': True}))
        row += 1
        summary_sheet.write(row, 0, '  With Website:')
        summary_sheet.write(row, 1, f'{with_website} ({with_website/max(len(leads), 1)*100:.1f}%)')
        row += 1
        summary_sheet.write(row, 0, '  Without Website:')
        summary_sheet.write(row, 1, f'{without_website} ({without_website/max(len(leads), 1)*100:.1f}%)')
        
        # Create Leads Sheet
        leads_sheet = workbook.add_worksheet('Leads')
        
        # Headers for leads sheet
        lead_headers = [
            'ID', 'Business Name', 'Phone', 'Website', 
            'Rating', 'Reviews', 'Status', 'Industry', 'Location',
            'Source', 'Has Website', 'Is Candidate',
            'Created', 'Updated', 'Last Call', 'Call Outcome', 
            'Has Screenshot', 'Notes',
            # PageSpeed columns
            'Mobile Score', 'Desktop Score', 'Mobile Perf', 'Desktop Perf',
            'FCP (s)', 'LCP (s)', 'CLS', 'TTI (s)', 'Speed Index',
            'PageSpeed Tested',
            # Conversion score columns
            'Conversion Score'
        ]
        
        # Write headers
        for col, header in enumerate(lead_headers):
            leads_sheet.write(0, col, header, header_format)
        
        # Write lead data
        for row_num, lead in enumerate(leads, start=1):
            # Get latest call for this lead
            latest_call = db.query(CallLog).filter(
                CallLog.lead_id == lead.id
            ).order_by(CallLog.called_at.desc()).first()
            
            # Write basic data
            leads_sheet.write(row_num, 0, lead.id, border_format)
            leads_sheet.write(row_num, 1, lead.business_name, border_format)
            leads_sheet.write(row_num, 2, lead.phone or '', border_format)
            leads_sheet.write(row_num, 3, lead.website_url or 'No Website', border_format)
            leads_sheet.write(row_num, 4, lead.rating or 0, border_format)
            leads_sheet.write(row_num, 5, lead.review_count or 0, border_format)
            
            # Status with color
            status_format = status_formats.get(lead.status, border_format)
            leads_sheet.write(row_num, 6, lead.status, status_format)
            
            # Continue with other fields
            leads_sheet.write(row_num, 7, lead.industry or '', border_format)
            leads_sheet.write(row_num, 8, lead.location or '', border_format)
            leads_sheet.write(row_num, 9, lead.source or '', border_format)
            leads_sheet.write(row_num, 10, 'Yes' if lead.has_website else 'No', border_format)
            leads_sheet.write(row_num, 11, 'Yes' if lead.is_candidate else 'No', border_format)
            
            # Dates
            if lead.created_at:
                leads_sheet.write_datetime(row_num, 12, lead.created_at, date_format)
            else:
                leads_sheet.write(row_num, 12, '', border_format)
                
            if lead.updated_at:
                leads_sheet.write_datetime(row_num, 13, lead.updated_at, date_format)
            else:
                leads_sheet.write(row_num, 13, '', border_format)
            
            # Call info
            if latest_call:
                leads_sheet.write_datetime(row_num, 14, latest_call.called_at, date_format)
                leads_sheet.write(row_num, 15, latest_call.outcome or '', border_format)
            else:
                leads_sheet.write(row_num, 14, 'Never', border_format)
                leads_sheet.write(row_num, 15, '', border_format)
            
            # Screenshot and notes
            leads_sheet.write(row_num, 16, 'Yes' if lead.screenshot_path else 'No', border_format)
            leads_sheet.write(row_num, 17, lead.notes or '', border_format)
            
            # PageSpeed data
            leads_sheet.write(row_num, 18, lead.pagespeed_mobile_score or '', border_format)
            leads_sheet.write(row_num, 19, lead.pagespeed_desktop_score or '', border_format)
            leads_sheet.write(row_num, 20, lead.pagespeed_mobile_performance or '', border_format)
            leads_sheet.write(row_num, 21, lead.pagespeed_desktop_performance or '', border_format)
            
            # Core Web Vitals
            if lead.pagespeed_first_contentful_paint:
                leads_sheet.write(row_num, 22, f"{lead.pagespeed_first_contentful_paint:.2f}", border_format)
            else:
                leads_sheet.write(row_num, 22, '', border_format)
                
            if lead.pagespeed_largest_contentful_paint:
                leads_sheet.write(row_num, 23, f"{lead.pagespeed_largest_contentful_paint:.2f}", border_format)
            else:
                leads_sheet.write(row_num, 23, '', border_format)
                
            if lead.pagespeed_cumulative_layout_shift:
                leads_sheet.write(row_num, 24, f"{lead.pagespeed_cumulative_layout_shift:.3f}", border_format)
            else:
                leads_sheet.write(row_num, 24, '', border_format)
                
            if lead.pagespeed_time_to_interactive:
                leads_sheet.write(row_num, 25, f"{lead.pagespeed_time_to_interactive:.2f}", border_format)
            else:
                leads_sheet.write(row_num, 25, '', border_format)
                
            if lead.pagespeed_speed_index:
                leads_sheet.write(row_num, 26, f"{lead.pagespeed_speed_index:.2f}", border_format)
            else:
                leads_sheet.write(row_num, 26, '', border_format)
                
            # PageSpeed test date
            if lead.pagespeed_tested_at:
                leads_sheet.write_datetime(row_num, 27, lead.pagespeed_tested_at, date_format)
            else:
                leads_sheet.write(row_num, 27, 'Not Tested', border_format)
            
            # Conversion score
            if lead.conversion_score is not None:
                leads_sheet.write(row_num, 28, f"{lead.conversion_score:.2%}", border_format)
            else:
                leads_sheet.write(row_num, 28, '', border_format)
        
        # Auto-fit columns
        for col in range(len(lead_headers)):
            leads_sheet.set_column(col, col, 15)
        leads_sheet.set_column(1, 1, 25)  # Business name
        leads_sheet.set_column(17, 17, 30)  # Notes
        
        # Create Timeline Sheet
        timeline_sheet = workbook.add_worksheet('Timeline')
        
        timeline_headers = ['Lead ID', 'Business Name', 'Date/Time', 'Event Type', 'Details', 'User']
        for col, header in enumerate(timeline_headers):
            timeline_sheet.write(0, col, header, header_format)
        
        timeline_row = 1
        for lead in leads:
            entries = db.query(LeadTimelineEntry).filter(
                LeadTimelineEntry.lead_id == lead.id
            ).order_by(LeadTimelineEntry.created_at.desc()).all()
            
            for entry in entries:
                timeline_sheet.write(timeline_row, 0, lead.id, border_format)
                timeline_sheet.write(timeline_row, 1, lead.business_name, border_format)
                timeline_sheet.write_datetime(timeline_row, 2, entry.created_at, date_format)
                timeline_sheet.write(timeline_row, 3, entry.type.value if hasattr(entry.type, 'value') else str(entry.type), border_format)
                timeline_sheet.write(timeline_row, 4, entry.description or entry.title or '', border_format)
                timeline_sheet.write(timeline_row, 5, entry.completed_by or 'System', border_format)
                timeline_row += 1
        
        # Auto-fit timeline columns
        timeline_sheet.set_column(0, 0, 10)
        timeline_sheet.set_column(1, 1, 25)
        timeline_sheet.set_column(2, 2, 18)
        timeline_sheet.set_column(3, 3, 15)
        timeline_sheet.set_column(4, 4, 50)
        timeline_sheet.set_column(5, 5, 15)
        
        # Create Call History Sheet
        calls_sheet = workbook.add_worksheet('Call History')
        
        call_headers = ['Lead ID', 'Business Name', 'Call Date', 'Duration (min)', 'Outcome', 'Notes']
        for col, header in enumerate(call_headers):
            calls_sheet.write(0, col, header, header_format)
        
        call_row = 1
        for lead in leads:
            calls = db.query(CallLog).filter(
                CallLog.lead_id == lead.id
            ).order_by(CallLog.called_at.desc()).all()
            
            for call in calls:
                calls_sheet.write(call_row, 0, lead.id, border_format)
                calls_sheet.write(call_row, 1, lead.business_name, border_format)
                calls_sheet.write_datetime(call_row, 2, call.called_at, date_format)
                calls_sheet.write(call_row, 3, call.duration_seconds or 0, border_format)
                calls_sheet.write(call_row, 4, call.outcome or '', border_format)
                calls_sheet.write(call_row, 5, call.notes or '', border_format)
                call_row += 1
        
        # Auto-fit call columns
        calls_sheet.set_column(0, 0, 10)
        calls_sheet.set_column(1, 1, 25)
        calls_sheet.set_column(2, 2, 18)
        calls_sheet.set_column(3, 3, 15)
        calls_sheet.set_column(4, 4, 20)
        calls_sheet.set_column(5, 5, 40)
        
        # Close workbook
        workbook.close()
        
        # Get the Excel file content
        output.seek(0)
        return output.getvalue()
        
    finally:
        db.close()