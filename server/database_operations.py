#!/usr/bin/env python3
"""
Database operations for lead management
"""

def save_lead_to_database(business_details, job_id=None, enable_pagespeed=False, max_pagespeed_score=None):
    """Immediately save a lead to the database as it's found"""
    try:
        from database import SessionLocal
        from models import Lead, LeadStatus
        from datetime import datetime
        from sqlalchemy import and_, or_, func
        
        db = SessionLocal()
        try:
            # Normalize data for duplicate checking
            business_name = business_details.get('name', 'Unknown Business').strip()
            location = business_details.get('location', 'Unknown').strip().lower()
            phone = (business_details.get('phone') or 'No phone').strip()
            profile_url = business_details.get('url', '').strip()
            
            # Check for duplicates using multiple strategies
            # Strategy 1: Exact match on business_name + location (case-insensitive)
            existing_lead = db.query(Lead).filter(
                and_(
                    func.lower(Lead.business_name) == func.lower(business_name),
                    func.lower(Lead.location) == func.lower(location)
                )
            ).first()
            
            # Strategy 2: If no exact match, check profile URL (Google Maps URL is unique)
            if not existing_lead and profile_url:
                existing_lead = db.query(Lead).filter(
                    Lead.profile_url == profile_url
                ).first()
            
            # Strategy 3: Check phone number if it's not "No phone" and location matches
            if not existing_lead and phone != 'No phone':
                existing_lead = db.query(Lead).filter(
                    and_(
                        Lead.phone == phone,
                        func.lower(Lead.location) == func.lower(location)
                    )
                ).first()
            
            if existing_lead:
                print(f"    ⚠️ Duplicate lead found: {business_name} in {location}")
                print(f"       Existing ID: {existing_lead.id}, Status: {existing_lead.status}")
                
                # Update certain fields if they're better in the new data
                updated = False
                
                # Update website if we found one and didn't have it before
                if not existing_lead.website_url and business_details.get('website'):
                    existing_lead.website_url = business_details.get('website')
                    existing_lead.has_website = True
                    updated = True
                    print(f"       ✅ Updated website URL: {business_details.get('website')}")
                
                # Update phone if we have a better one
                if existing_lead.phone == 'No phone' and phone != 'No phone':
                    existing_lead.phone = phone
                    updated = True
                    print(f"       ✅ Updated phone: {phone}")
                
                # Update screenshot if we have a new one
                if business_details.get('screenshot_filename') and not existing_lead.screenshot_path:
                    existing_lead.screenshot_path = business_details.get('screenshot_filename')
                    updated = True
                    print(f"       ✅ Updated screenshot")
                
                # Update ratings/reviews if they're newer
                if business_details.get('rating') and business_details.get('reviews'):
                    new_rating = float(business_details.get('rating', 0.0))
                    new_reviews = int(business_details.get('reviews', 0))
                    if new_reviews > (existing_lead.review_count or 0):
                        existing_lead.rating = new_rating
                        existing_lead.review_count = new_reviews
                        updated = True
                        print(f"       ✅ Updated rating/reviews: {new_rating}★ ({new_reviews} reviews)")
                
                if updated:
                    existing_lead.updated_at = datetime.utcnow()
                    db.commit()
                    print(f"       💾 Updated existing lead with new information")
                
                return existing_lead
            
            # No duplicate found, create new lead
            lead = Lead(
                business_name=business_name,
                industry=business_details.get('industry', 'Unknown'),
                rating=float(business_details.get('rating', 0.0)),
                review_count=int(business_details.get('reviews', 0)),
                website_url=business_details.get('website'),
                has_website=business_details.get('has_website', False),
                phone=phone,
                profile_url=profile_url,
                location=location,
                status=LeadStatus.new,
                has_recent_reviews=business_details.get('has_recent_reviews', True),
                screenshot_path=business_details.get('screenshot_filename')
            )
            
            db.add(lead)
            db.commit()
            
            # Create "Lead Created" timeline entry
            from models import LeadTimelineEntry, TimelineEntryType
            import uuid
            from datetime import datetime
            
            timeline_entry = LeadTimelineEntry(
                id=str(uuid.uuid4()),
                lead_id=lead.id,
                type=TimelineEntryType.LEAD_CREATED,
                title="Lead Created",
                description=f"Lead discovered from {business_details.get('industry', 'Unknown')} search in {business_details.get('location', 'Unknown')}. {'Has website' if lead.has_website else 'No website (candidate)'}",
                created_at=datetime.utcnow()
            )
            db.add(timeline_entry)
            db.commit()
            
            print(f"    💾 Saved lead to database: {lead.business_name} (ID: {lead.id})")
            print(f"    📝 Created timeline entry: Lead Created")
            
            # Broadcast new lead via WebSocket
            try:
                from websocket_manager import pagespeed_websocket_manager
                import asyncio
                loop = asyncio.new_event_loop()
                asyncio.set_event_loop(loop)
                loop.run_until_complete(pagespeed_websocket_manager.broadcast_pagespeed_update(
                    lead_id=lead.id,
                    update_type="lead_created",
                    data={
                        "business_name": lead.business_name,
                        "location": lead.location,
                        "has_website": lead.has_website,
                        "source_job_id": job_id
                    }
                ))
                print(f"    📡 Broadcasted new lead notification for {lead.business_name}")
            except Exception as ws_error:
                print(f"    ⚠️ Could not broadcast new lead notification: {ws_error}")
            
            # Trigger PageSpeed test if enabled and lead has website
            print(f"    🔍 PageSpeed check: enable_pagespeed={enable_pagespeed}, has_website={lead.has_website}, website_url={lead.website_url}")
            if enable_pagespeed and lead.has_website and lead.website_url:
                try:
                    # Handle Google Ads redirect URLs by following to final destination
                    final_url = lead.website_url
                    if 'google.com/aclk' in lead.website_url or 'googleadservices.com' in lead.website_url:
                        print(f"    🔄 Detected Google Ads URL, following redirect...")
                        import requests
                        from urllib.parse import urlparse, urlunparse
                        try:
                            # Follow redirects to get final URL
                            response = requests.head(lead.website_url, allow_redirects=True, timeout=5)
                            final_url = response.url
                            print(f"    ✅ Resolved to actual website: {final_url}")
                            
                            # Clean up tracking parameters from URL
                            parsed = urlparse(final_url)
                            # Keep only the scheme, netloc, and path - remove query params and fragments
                            clean_url = urlunparse((parsed.scheme, parsed.netloc, parsed.path, '', '', ''))
                            # Remove trailing slash for consistency
                            clean_url = clean_url.rstrip('/')
                            print(f"    🧹 Cleaned URL: {clean_url}")
                            
                            # Update lead with clean website URL
                            lead.website_url = clean_url
                            final_url = clean_url
                            db.commit()
                        except Exception as e:
                            print(f"    ⚠️ Could not follow redirect: {str(e)}")
                            # Still try with original URL if redirect fails
                            final_url = lead.website_url
                    
                    from pagespeed_service import pagespeed_service
                    print(f"    🚀 Queuing PageSpeed test for {lead.business_name} - {final_url} (max_score={max_pagespeed_score})")
                    pagespeed_service.test_during_generation(str(lead.id), final_url, max_pagespeed_score)
                    print(f"    ✅ PageSpeed test queued successfully for {lead.business_name}")
                except Exception as e:
                    print(f"    ⚠️ Could not queue PageSpeed test: {str(e)}")
            
            return lead.id
            
        except Exception as e:
            db.rollback()
            print(f"    ❌ Error saving lead to database: {str(e)}")
            return None
        finally:
            db.close()
            
    except Exception as e:
        print(f"    ❌ Database connection error: {str(e)}")
        return None