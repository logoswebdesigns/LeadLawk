#!/usr/bin/env python3
"""
Analytics engine for conversion insights and pattern recognition
"""

from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional
from sqlalchemy import func, and_, or_, case
from sqlalchemy.orm import Session
from database import SessionLocal
from models import Lead, LeadStatus, LeadTimelineEntry


class AnalyticsEngine:
    """Generate analytics and insights from lead data"""
    
    @staticmethod
    def get_conversion_overview(db: Session) -> Dict[str, Any]:
        """Get overall conversion metrics"""
        total_leads = db.query(Lead).count()
        
        # Return empty state if no data
        if total_leads == 0:
            return {
                "total_leads": 0,
                "converted": 0,
                "interested": 0,
                "called": 0,
                "dnc": 0,
                "new": 0,
                "conversion_rate": 0.0,
                "interest_rate": 0.0,
                "contact_rate": 0.0
            }
        
        converted = db.query(Lead).filter(Lead.status == LeadStatus.converted).count()
        interested = db.query(Lead).filter(Lead.status == LeadStatus.interested).count()
        called = db.query(Lead).filter(Lead.status == LeadStatus.called).count()
        dnc = db.query(Lead).filter(Lead.status == LeadStatus.doNotCall).count()
        new = db.query(Lead).filter(Lead.status == LeadStatus.new).count()
        
        conversion_rate = (converted / total_leads * 100) if total_leads > 0 else 0
        interest_rate = (interested / total_leads * 100) if total_leads > 0 else 0
        contact_rate = ((called + interested + converted) / total_leads * 100) if total_leads > 0 else 0
        
        return {
            "total_leads": total_leads,
            "converted": converted,
            "interested": interested,
            "called": called,
            "dnc": dnc,
            "new": new,
            "conversion_rate": round(conversion_rate, 1),
            "interest_rate": round(interest_rate, 1),
            "contact_rate": round(contact_rate, 1)
        }
    
    @staticmethod
    def get_top_converting_segments(db: Session, limit: int = 10) -> Dict[str, List[Dict]]:
        """Identify top converting segments by various dimensions"""
        
        # Check if we have any data
        total_leads = db.query(Lead).count()
        if total_leads == 0:
            return {
                "top_industries": [],
                "top_locations": [],
                "rating_performance": [],
                "review_performance": []
            }
        
        # Top converting industries
        industry_stats = db.query(
            Lead.industry,
            func.count(Lead.id).label('total'),
            func.sum(case((Lead.status == LeadStatus.converted, 1), else_=0)).label('converted'),
            func.sum(case((Lead.status == LeadStatus.interested, 1), else_=0)).label('interested')
        ).group_by(Lead.industry).having(func.count(Lead.id) >= 3).all()
        
        top_industries = []
        for stat in industry_stats:
            if stat.industry and stat.total > 0:
                conversion_rate = (stat.converted / stat.total) * 100
                interest_rate = (stat.interested / stat.total) * 100
                top_industries.append({
                    "industry": stat.industry,
                    "total_leads": stat.total,
                    "converted": stat.converted,
                    "interested": stat.interested,
                    "conversion_rate": round(conversion_rate, 1),
                    "interest_rate": round(interest_rate, 1),
                    "success_score": round(conversion_rate + (interest_rate * 0.5), 1)
                })
        
        top_industries.sort(key=lambda x: x['success_score'], reverse=True)
        
        # Top converting locations
        location_stats = db.query(
            Lead.location,
            func.count(Lead.id).label('total'),
            func.sum(case((Lead.status == LeadStatus.converted, 1), else_=0)).label('converted'),
            func.sum(case((Lead.status == LeadStatus.interested, 1), else_=0)).label('interested')
        ).group_by(Lead.location).having(func.count(Lead.id) >= 3).all()
        
        top_locations = []
        for stat in location_stats:
            if stat.location and stat.total > 0:
                conversion_rate = (stat.converted / stat.total) * 100
                interest_rate = (stat.interested / stat.total) * 100
                top_locations.append({
                    "location": stat.location,
                    "total_leads": stat.total,
                    "converted": stat.converted,
                    "interested": stat.interested,
                    "conversion_rate": round(conversion_rate, 1),
                    "interest_rate": round(interest_rate, 1),
                    "success_score": round(conversion_rate + (interest_rate * 0.5), 1)
                })
        
        top_locations.sort(key=lambda x: x['success_score'], reverse=True)
        
        # Rating band analysis
        rating_bands = [
            (4.5, 5.0, "4.5-5.0 ⭐"),
            (4.0, 4.5, "4.0-4.5 ⭐"),
            (3.5, 4.0, "3.5-4.0 ⭐"),
            (0.0, 3.5, "Below 3.5 ⭐")
        ]
        
        rating_performance = []
        for min_rating, max_rating, label in rating_bands:
            band_stats = db.query(
                func.count(Lead.id).label('total'),
                func.sum(case((Lead.status == LeadStatus.converted, 1), else_=0)).label('converted'),
                func.sum(case((Lead.status == LeadStatus.interested, 1), else_=0)).label('interested')
            ).filter(
                and_(Lead.rating >= min_rating, Lead.rating < max_rating)
            ).first()
            
            if band_stats and band_stats.total > 0:
                conversion_rate = (band_stats.converted / band_stats.total) * 100
                interest_rate = (band_stats.interested / band_stats.total) * 100
                rating_performance.append({
                    "rating_band": label,
                    "total_leads": band_stats.total,
                    "converted": band_stats.converted,
                    "interested": band_stats.interested,
                    "conversion_rate": round(conversion_rate, 1),
                    "interest_rate": round(interest_rate, 1),
                    "success_score": round(conversion_rate + (interest_rate * 0.5), 1)
                })
        
        rating_performance.sort(key=lambda x: x['success_score'], reverse=True)
        
        # Review count analysis
        review_bands = [
            (100, 999999, "100+ reviews"),
            (50, 100, "50-99 reviews"),
            (20, 50, "20-49 reviews"),
            (10, 20, "10-19 reviews"),
            (0, 10, "Under 10 reviews")
        ]
        
        review_performance = []
        for min_reviews, max_reviews, label in review_bands:
            band_stats = db.query(
                func.count(Lead.id).label('total'),
                func.sum(case((Lead.status == LeadStatus.converted, 1), else_=0)).label('converted'),
                func.sum(case((Lead.status == LeadStatus.interested, 1), else_=0)).label('interested')
            ).filter(
                and_(Lead.review_count >= min_reviews, Lead.review_count < max_reviews)
            ).first()
            
            if band_stats and band_stats.total > 0:
                conversion_rate = (band_stats.converted / band_stats.total) * 100
                interest_rate = (band_stats.interested / band_stats.total) * 100
                review_performance.append({
                    "review_band": label,
                    "total_leads": band_stats.total,
                    "converted": band_stats.converted,
                    "interested": band_stats.interested,
                    "conversion_rate": round(conversion_rate, 1),
                    "interest_rate": round(interest_rate, 1),
                    "success_score": round(conversion_rate + (interest_rate * 0.5), 1)
                })
        
        review_performance.sort(key=lambda x: x['success_score'], reverse=True)
        
        return {
            "top_industries": top_industries[:limit],
            "top_locations": top_locations[:limit],
            "rating_performance": rating_performance,
            "review_performance": review_performance
        }
    
    @staticmethod
    def get_conversion_timeline(db: Session, days: int = 30) -> List[Dict]:
        """Get conversion trends over time"""
        end_date = datetime.utcnow()
        start_date = end_date - timedelta(days=days)
        
        # Get daily conversion data
        daily_data = []
        current_date = start_date
        
        while current_date <= end_date:
            next_date = current_date + timedelta(days=1)
            
            # Count conversions for this day
            conversions = db.query(LeadTimelineEntry).filter(
                and_(
                    LeadTimelineEntry.entry_type == 'STATUS_CHANGE',
                    LeadTimelineEntry.content.like('%CONVERTED%'),
                    LeadTimelineEntry.created_at >= current_date,
                    LeadTimelineEntry.created_at < next_date
                )
            ).count()
            
            # Count new leads for this day
            new_leads = db.query(Lead).filter(
                and_(
                    Lead.created_at >= current_date,
                    Lead.created_at < next_date
                )
            ).count()
            
            daily_data.append({
                "date": current_date.strftime("%Y-%m-%d"),
                "conversions": conversions,
                "new_leads": new_leads
            })
            
            current_date = next_date
        
        return daily_data
    
    @staticmethod
    def get_actionable_insights(db: Session) -> List[Dict]:
        """Generate actionable insights based on data patterns"""
        insights = []
        
        # Get overview for context
        overview = AnalyticsEngine.get_conversion_overview(db)
        
        # If no data, return empty insights
        if overview['total_leads'] == 0:
            return []
        
        segments = AnalyticsEngine.get_top_converting_segments(db)
        
        # Insight 1: Best performing industry
        if segments['top_industries']:
            best_industry = segments['top_industries'][0]
            if best_industry['success_score'] > 20:
                insights.append({
                    "type": "opportunity",
                    "title": f"Focus on {best_industry['industry']}",
                    "description": f"{best_industry['industry']} shows {best_industry['conversion_rate']}% conversion rate with {best_industry['total_leads']} leads",
                    "action": f"Prioritize {best_industry['industry']} businesses in your outreach",
                    "impact": "high"
                })
        
        # Insight 2: Location patterns
        if segments['top_locations']:
            best_location = segments['top_locations'][0]
            if best_location['success_score'] > 15:
                insights.append({
                    "type": "opportunity",
                    "title": f"Success in {best_location['location']}",
                    "description": f"{best_location['location']} area showing {best_location['conversion_rate']}% conversion",
                    "action": f"Expand search for more businesses in {best_location['location']}",
                    "impact": "high"
                })
        
        # Insight 3: Rating sweet spot
        if segments['rating_performance']:
            best_rating = segments['rating_performance'][0]
            insights.append({
                "type": "pattern",
                "title": f"Rating Sweet Spot: {best_rating['rating_band']}",
                "description": f"Businesses with {best_rating['rating_band']} convert at {best_rating['conversion_rate']}%",
                "action": "Target businesses in this rating range",
                "impact": "medium"
            })
        
        # Insight 4: Review count pattern
        if segments['review_performance']:
            best_review_band = segments['review_performance'][0]
            insights.append({
                "type": "pattern",
                "title": f"Optimal Review Count: {best_review_band['review_band']}",
                "description": f"Businesses with {best_review_band['review_band']} show {best_review_band['success_score']}% success score",
                "action": "Filter searches for this review count range",
                "impact": "medium"
            })
        
        # Insight 5: Untapped leads
        new_leads_count = overview['new']
        if new_leads_count > 10:
            insights.append({
                "type": "action",
                "title": f"{new_leads_count} Untapped Leads",
                "description": f"You have {new_leads_count} leads that haven't been contacted yet",
                "action": "Start calling your newest leads",
                "impact": "high"
            })
        
        # Insight 6: Follow-up opportunities
        interested_count = overview['interested']
        if interested_count > 0:
            insights.append({
                "type": "action",
                "title": f"{interested_count} Warm Leads",
                "description": f"{interested_count} leads marked as interested need follow-up",
                "action": "Follow up with interested leads to close deals",
                "impact": "high"
            })
        
        return insights