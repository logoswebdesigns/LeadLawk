#!/usr/bin/env python3
"""
PageSpeed Insights API integration service
Uses Google's PageSpeed Insights API to analyze website performance
"""

import os
import uuid
import asyncio
import aiohttp
import logging
from datetime import datetime
from typing import Dict, List, Optional, Any
from concurrent.futures import ThreadPoolExecutor
from urllib.parse import urlparse, urljoin

from sqlalchemy.orm import Session
from database import SessionLocal
from models import Lead, LeadTimelineEntry, TimelineEntryType

logger = logging.getLogger(__name__)

class PageSpeedService:
    """Service for running PageSpeed Insights tests on lead websites"""
    
    def __init__(self):
        self.api_key = os.getenv('PAGESPEED_API_KEY', 'AIzaSyBsPycGUwl4ekU52qfa2vslGqCxFee6-pQ')
        self.base_url = 'https://www.googleapis.com/pagespeedonline/v5/runPagespeed'
        # Increased thread pool for parallel PageSpeed testing - runs independently of Selenium
        self.executor = ThreadPoolExecutor(max_workers=20)  # Support hundreds of parallel API calls
        
    async def test_website(self, url: str, strategy: str = 'mobile') -> Dict[str, Any]:
        """
        Run PageSpeed test on a single URL
        Strategy can be 'mobile' or 'desktop'
        """
        # Ensure URL has protocol
        if not url.startswith(('http://', 'https://')):
            url = f'https://{url}'
            
        params = {
            'url': url,
            'key': self.api_key,
            'strategy': strategy,
            'category': ['performance', 'accessibility', 'best-practices', 'seo']
        }
        
        start_time = datetime.now()
        logger.info(f"🚀 Starting PageSpeed test for {url} ({strategy}) at {start_time}")
        print(f"🚀 Starting PageSpeed test for {url} ({strategy}) at {start_time}")
        
        try:
            timeout = aiohttp.ClientTimeout(total=120, connect=10, sock_read=120)
            async with aiohttp.ClientSession(timeout=timeout) as session:
                logger.info(f"📡 Sending request to PageSpeed API...")
                print(f"📡 Making PageSpeed API request to: {self.base_url}")
                print(f"📡 Request params: url={url}, strategy={strategy}")
                async with session.get(self.base_url, params=params) as response:
                    elapsed = (datetime.now() - start_time).total_seconds()
                    logger.info(f"📊 Got response status {response.status} after {elapsed:.1f}s")
                    
                    if response.status == 200:
                        data = await response.json()
                        elapsed = (datetime.now() - start_time).total_seconds()
                        logger.info(f"✅ PageSpeed test completed for {url} ({strategy}) in {elapsed:.1f}s")
                        print(f"✅ PageSpeed test completed for {url} ({strategy}) in {elapsed:.1f}s")
                        return self._parse_pagespeed_results(data, strategy)
                    else:
                        error_text = await response.text()
                        logger.error(f"❌ PageSpeed API error {response.status}: {error_text}")
                        return {'error': f'API error {response.status}: {error_text}'}
        except asyncio.TimeoutError:
            elapsed = (datetime.now() - start_time).total_seconds()
            error_msg = f'PageSpeed test timeout after {elapsed:.1f}s - website may be slow or unreachable'
            logger.error(f"⏱️ {error_msg} for {url}")
            print(f"⏱️ {error_msg} for {url}")
            return {'error': error_msg}
        except aiohttp.ClientError as e:
            elapsed = (datetime.now() - start_time).total_seconds()
            error_msg = f"Network error after {elapsed:.1f}s: {str(e)}"
            logger.error(f"🌐 {error_msg} for {url}")
            return {'error': error_msg}
        except Exception as e:
            elapsed = (datetime.now() - start_time).total_seconds()
            logger.error(f"💥 PageSpeed test error for {url} after {elapsed:.1f}s: {str(e)}")
            return {'error': str(e)}
    
    def _parse_pagespeed_results(self, data: Dict, strategy: str) -> Dict[str, Any]:
        """Parse PageSpeed API response into structured data"""
        try:
            lighthouse = data.get('lighthouseResult', {})
            categories = lighthouse.get('categories', {})
            audits = lighthouse.get('audits', {})
            
            # Extract scores (0-100)
            performance_score = int(categories.get('performance', {}).get('score', 0) * 100)
            accessibility_score = int(categories.get('accessibility', {}).get('score', 0) * 100)
            best_practices_score = int(categories.get('best-practices', {}).get('score', 0) * 100)
            seo_score = int(categories.get('seo', {}).get('score', 0) * 100)
            
            # Extract performance metrics (in milliseconds)
            fcp = audits.get('first-contentful-paint', {}).get('numericValue', 0)
            lcp = audits.get('largest-contentful-paint', {}).get('numericValue', 0)
            tbt = audits.get('total-blocking-time', {}).get('numericValue', 0)
            cls = audits.get('cumulative-layout-shift', {}).get('numericValue', 0)
            si = audits.get('speed-index', {}).get('numericValue', 0)
            tti = audits.get('interactive', {}).get('numericValue', 0)
            
            # Extract screenshot data
            screenshot_data = None
            final_screenshot = audits.get('final-screenshot', {})
            if final_screenshot and 'details' in final_screenshot:
                screenshot_data = final_screenshot['details'].get('data')  # Base64 encoded image
            
            # Also check for full-page screenshot
            full_page_screenshot = audits.get('full-page-screenshot', {})
            if not screenshot_data and full_page_screenshot and 'details' in full_page_screenshot:
                screenshot_data = full_page_screenshot['details'].get('screenshot', {}).get('data')
            
            return {
                'strategy': strategy,
                'performance_score': performance_score,
                'accessibility_score': accessibility_score,
                'best_practices_score': best_practices_score,
                'seo_score': seo_score,
                'metrics': {
                    'first_contentful_paint': fcp / 1000,  # Convert to seconds
                    'largest_contentful_paint': lcp / 1000,
                    'total_blocking_time': tbt / 1000,
                    'cumulative_layout_shift': cls,
                    'speed_index': si / 1000,
                    'time_to_interactive': tti / 1000,
                },
                'tested_url': data.get('id'),
                'final_url': lighthouse.get('finalUrl'),
                'screenshot_data': screenshot_data,  # Base64 encoded screenshot
            }
        except Exception as e:
            logger.error(f"Error parsing PageSpeed results: {str(e)}")
            return {'error': f'Failed to parse results: {str(e)}'}
    
    async def test_lead_website(self, lead_id: str) -> Dict[str, Any]:
        """Test a lead's website with both mobile and desktop strategies"""
        print(f"test_lead_website called for lead_id: {lead_id}")
        logger.info(f"test_lead_website called for lead_id: {lead_id}")
        
        db = SessionLocal()
        try:
            lead = db.query(Lead).filter(Lead.id == lead_id).first()
            if not lead:
                logger.error(f"Lead {lead_id} not found")
                return {'error': 'Lead not found'}
            
            if not lead.website_url:
                logger.error(f"Lead {lead_id} has no website")
                return {'error': 'Lead has no website'}
            
            logger.info(f"Testing website: {lead.website_url}")
            print(f"Testing website: {lead.website_url}")
            
            # Run both mobile and desktop tests in parallel
            mobile_task = asyncio.create_task(self.test_website(lead.website_url, 'mobile'))
            desktop_task = asyncio.create_task(self.test_website(lead.website_url, 'desktop'))
            
            mobile_results, desktop_results = await asyncio.gather(mobile_task, desktop_task)
            
            # Update lead with results
            if 'error' not in mobile_results:
                lead.pagespeed_mobile_score = mobile_results['performance_score']
                lead.pagespeed_mobile_performance = mobile_results['performance_score'] / 100.0
                lead.pagespeed_accessibility_score = mobile_results['accessibility_score']
                lead.pagespeed_best_practices_score = mobile_results['best_practices_score']
                lead.pagespeed_seo_score = mobile_results['seo_score']
                
                # Store detailed metrics
                metrics = mobile_results['metrics']
                lead.pagespeed_first_contentful_paint = metrics['first_contentful_paint']
                lead.pagespeed_largest_contentful_paint = metrics['largest_contentful_paint']
                lead.pagespeed_total_blocking_time = metrics['total_blocking_time']
                lead.pagespeed_cumulative_layout_shift = metrics['cumulative_layout_shift']
                lead.pagespeed_speed_index = metrics['speed_index']
                lead.pagespeed_time_to_interactive = metrics['time_to_interactive']
            
            if 'error' not in desktop_results:
                lead.pagespeed_desktop_score = desktop_results['performance_score']
                lead.pagespeed_desktop_performance = desktop_results['performance_score'] / 100.0
            
            # Save screenshot if available
            screenshot_path = None
            screenshot_data = mobile_results.get('screenshot_data') or desktop_results.get('screenshot_data')
            if screenshot_data:
                try:
                    import base64
                    import os
                    
                    # Create screenshots directory if it doesn't exist
                    screenshots_dir = '/app/website_screenshots' if os.getenv('USE_DOCKER') else './website_screenshots'
                    os.makedirs(screenshots_dir, exist_ok=True)
                    
                    # Generate filename
                    safe_name = "".join(c for c in lead.business_name if c.isalnum() or c in (' ', '-', '_')).rstrip()[:20]
                    screenshot_filename = f"website_{lead_id}_{safe_name}.png"
                    screenshot_path = os.path.join(screenshots_dir, screenshot_filename)
                    
                    # Decode base64 and save
                    image_data = base64.b64decode(screenshot_data.split(',')[1] if ',' in screenshot_data else screenshot_data)
                    with open(screenshot_path, 'wb') as f:
                        f.write(image_data)
                    
                    # Store relative path in database
                    lead.website_screenshot_path = screenshot_filename
                    logger.info(f"✅ Saved website screenshot: {screenshot_filename}")
                except Exception as e:
                    logger.error(f"Failed to save screenshot: {str(e)}")
            
            # Set test timestamp
            lead.pagespeed_tested_at = datetime.utcnow()
            
            # Handle errors
            if 'error' in mobile_results and 'error' in desktop_results:
                lead.pagespeed_test_error = f"Mobile: {mobile_results['error']}, Desktop: {desktop_results['error']}"
            elif 'error' in mobile_results:
                lead.pagespeed_test_error = f"Mobile: {mobile_results['error']}"
            elif 'error' in desktop_results:
                lead.pagespeed_test_error = f"Desktop: {desktop_results['error']}"
            else:
                lead.pagespeed_test_error = None
            
            # Add timeline entry
            timeline_entry = LeadTimelineEntry(
                id=f"{lead_id}_{datetime.utcnow().timestamp()}",
                lead_id=lead_id,
                type=TimelineEntryType.NOTE,
                title="PageSpeed Test Completed",
                description=f"Mobile Score: {mobile_results.get('performance_score', 'N/A')}, Desktop Score: {desktop_results.get('performance_score', 'N/A')}",
                created_at=datetime.utcnow()
            )
            db.add(timeline_entry)
            
            db.commit()
            
            # Broadcast PageSpeed update via WebSocket
            try:
                from websocket_manager import pagespeed_websocket_manager
                asyncio.create_task(pagespeed_websocket_manager.broadcast_pagespeed_update(
                    lead_id=lead_id,
                    update_type="score_received",
                    data={
                        "mobile_score": mobile_results.get('performance_score'),
                        "desktop_score": desktop_results.get('performance_score'),
                        "has_error": bool(lead.pagespeed_test_error)
                    }
                ))
            except Exception as e:
                logger.warning(f"Could not broadcast PageSpeed update: {e}")
            
            return {
                'lead_id': lead_id,
                'mobile': mobile_results,
                'desktop': desktop_results,
                'status': 'completed'
            }
            
        except Exception as e:
            logger.error(f"Error testing lead {lead_id}: {str(e)}")
            return {'error': str(e)}
        finally:
            db.close()
    
    async def test_multiple_leads(self, lead_ids: List[str], max_concurrent: int = 5) -> List[Dict[str, Any]]:
        """Test multiple leads with rate limiting"""
        semaphore = asyncio.Semaphore(max_concurrent)
        
        async def test_with_limit(lead_id: str):
            async with semaphore:
                return await self.test_lead_website(lead_id)
        
        tasks = [test_with_limit(lead_id) for lead_id in lead_ids]
        results = await asyncio.gather(*tasks)
        return results
    
    def test_during_generation(self, lead_id: str, website_url: str, max_pagespeed_score: int = 100) -> None:
        """
        Test a website during lead generation (non-blocking)
        Runs in background thread to not slow down scraping
        Will delete lead if PageSpeed score exceeds max_pagespeed_score
        """
        print(f"    🚀🚀🚀 test_during_generation called for lead {lead_id} with website {website_url}, max_score={max_pagespeed_score}")
        logger.info(f"🚀🚀🚀 test_during_generation called for lead {lead_id} with website {website_url}, max_score={max_pagespeed_score}")
        
        def run_test():
            try:
                print(f"    🔄 Starting background PageSpeed test for lead {lead_id}")
                logger.info(f"🔄 Starting background PageSpeed test for lead {lead_id}")
                # Create new event loop for thread
                loop = asyncio.new_event_loop()
                asyncio.set_event_loop(loop)
                result = loop.run_until_complete(self.test_lead_website(lead_id))
                
                # Create a log-friendly version without screenshot data
                log_result = {k: v for k, v in result.items() if k != 'screenshot_data'}
                if 'mobile' in result:
                    log_result['mobile'] = {k: v for k, v in result['mobile'].items() if k != 'screenshot_data'}
                if 'desktop' in result:
                    log_result['desktop'] = {k: v for k, v in result['desktop'].items() if k != 'screenshot_data'}
                
                print(f"    ✅ PageSpeed test completed for lead {lead_id}: scores={log_result.get('mobile', {}).get('performance_score', 'N/A')}/{log_result.get('desktop', {}).get('performance_score', 'N/A')} (mobile/desktop)")
                logger.info(f"✅ PageSpeed test completed for lead {lead_id}: {log_result}")
                
                # Check if we should delete the lead based on PageSpeed score
                print(f"    🔍 Checking PageSpeed deletion: error_in_result={'error' in result}, max_score={max_pagespeed_score}")
                if 'error' not in result and max_pagespeed_score is not None and max_pagespeed_score < 100:
                    db = SessionLocal()
                    lead_deleted = False
                    try:
                        lead = db.query(Lead).filter(Lead.id == lead_id).first()
                        print(f"    🔍 Lead check: found={lead is not None}, mobile_score={lead.pagespeed_mobile_score if lead else 'N/A'}, max_score={max_pagespeed_score}")
                        if lead and lead.pagespeed_mobile_score is not None and max_pagespeed_score is not None:
                            if lead.pagespeed_mobile_score > max_pagespeed_score:
                                print(f"    🗑️ Deleting lead {lead.business_name} - PageSpeed score {lead.pagespeed_mobile_score} exceeds threshold {max_pagespeed_score}")
                                logger.info(f"🗑️ Deleting lead {lead.business_name} - PageSpeed score {lead.pagespeed_mobile_score} exceeds threshold {max_pagespeed_score}")
                                
                                # Add deletion timeline entry before deleting
                                timeline_entry = LeadTimelineEntry(
                                    id=str(uuid.uuid4()),
                                    lead_id=lead.id,
                                    type=TimelineEntryType.NOTE,
                                    title="Lead Auto-Deleted",
                                    description=f"Lead automatically deleted due to PageSpeed score ({lead.pagespeed_mobile_score}) exceeding threshold ({max_pagespeed_score})",
                                    created_at=datetime.now()
                                )
                                db.add(timeline_entry)
                                db.commit()
                                db.close()  # Close the current session before calling delete_lead_by_id
                                
                                # Broadcast deletion via WebSocket BEFORE deleting
                                try:
                                    from websocket_manager import pagespeed_websocket_manager
                                    loop = asyncio.new_event_loop()
                                    asyncio.set_event_loop(loop)
                                    loop.run_until_complete(pagespeed_websocket_manager.broadcast_pagespeed_update(
                                        lead_id=lead_id,
                                        update_type="lead_deleted",
                                        data={
                                            "reason": f"PageSpeed score {lead.pagespeed_mobile_score} exceeds threshold {max_pagespeed_score}",
                                            "mobile_score": lead.pagespeed_mobile_score,
                                            "threshold": max_pagespeed_score
                                        }
                                    ))
                                except Exception as ws_error:
                                    logger.warning(f"Could not broadcast deletion update: {ws_error}")
                                
                                # Wait for animation to play before deleting (2.5 seconds to ensure frontend animation completes)
                                import time
                                print(f"    ⏳ Waiting 2.5 seconds for deletion animation to play...")
                                time.sleep(2.5)
                                
                                # Delete the lead using the proper function that also deletes screenshots
                                from lead_management import delete_lead_by_id
                                if delete_lead_by_id(lead_id):
                                    print(f"    ✅ Lead deleted successfully (including screenshots)")
                                else:
                                    print(f"    ⚠️ Failed to delete lead")
                                lead_deleted = True  # Mark that we've already closed the db
                            else:
                                print(f"    ✅ Lead retained - PageSpeed score {lead.pagespeed_mobile_score} is within threshold {max_pagespeed_score}")
                    except Exception as e:
                        print(f"    ❌ Error checking/deleting lead after PageSpeed test: {str(e)}")
                        logger.error(f"❌ Error checking/deleting lead after PageSpeed test: {str(e)}")
                    finally:
                        if not lead_deleted:  # Only close if we haven't already closed it
                            db.close()
                        
            except Exception as e:
                print(f"    ❌ Background PageSpeed test failed for {lead_id}: {str(e)}")
                logger.error(f"❌ Background PageSpeed test failed for {lead_id}: {str(e)}")
        
        # Submit to executor for background processing
        future = self.executor.submit(run_test)
        print(f"    📋 PageSpeed test submitted to executor for lead {lead_id}")
        logger.info(f"📋 PageSpeed test submitted to executor for lead {lead_id}")
    
    def get_performance_category(self, score: Optional[int]) -> str:
        """Categorize performance score"""
        if score is None:
            return 'untested'
        elif score >= 90:
            return 'good'
        elif score >= 50:
            return 'needs_improvement'
        else:
            return 'poor'
    
    def test_lead_async(self, lead_id: int, website_url: str) -> None:
        """Async wrapper for testing a single lead"""
        try:
            logger.info(f"Starting async PageSpeed test for lead {lead_id}, website: {website_url}")
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
            result = loop.run_until_complete(self.test_lead_website(str(lead_id)))
            
            # Create a log-friendly version without screenshot data
            log_result = {k: v for k, v in result.items() if k != 'screenshot_data'}
            if 'mobile' in result:
                log_result['mobile'] = {k: v for k, v in result['mobile'].items() if k != 'screenshot_data'}
            if 'desktop' in result:
                log_result['desktop'] = {k: v for k, v in result['desktop'].items() if k != 'screenshot_data'}
                
            logger.info(f"PageSpeed test completed for lead {lead_id}: {log_result}")
        except Exception as e:
            logger.error(f"Failed to run PageSpeed test for lead {lead_id}: {str(e)}")
    
    def test_multiple_leads_async(self, lead_data: List[tuple]) -> None:
        """Async wrapper for testing multiple leads"""
        lead_ids = [str(lead_id) for lead_id, _ in lead_data]
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        loop.run_until_complete(self.test_multiple_leads(lead_ids))
    
    def get_testing_status(self) -> Dict[str, Any]:
        """Get current testing status"""
        return {
            "active_tests": 0,  # Would need to track this
            "completed_today": 0,  # Would need to track this
            "api_key_valid": bool(self.api_key),
            "rate_limit": "50 requests per second"
        }


# Global service instance
pagespeed_service = PageSpeedService()