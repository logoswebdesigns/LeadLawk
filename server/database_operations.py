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
        
        db = SessionLocal()
        try:
            # Create the lead record
            lead = Lead(
                business_name=business_details.get('name', 'Unknown Business'),
                industry=business_details.get('industry', 'Unknown'),
                rating=float(business_details.get('rating', 0.0)),
                review_count=int(business_details.get('reviews', 0)),
                website_url=business_details.get('website'),
                has_website=business_details.get('has_website', False),
                phone=business_details.get('phone') or 'No phone',
                profile_url=business_details.get('url'),  # Google Maps URL
                location=business_details.get('location', 'Unknown'),
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