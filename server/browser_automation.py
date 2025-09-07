#!/usr/bin/env python3
"""
Refactored Browser Automation - Main orchestration class
"""

from browser_setup import BrowserSetup
from screenshot_manager import ScreenshotManager
from search_area_manager import SearchAreaManager
from maps_search_engine import MapsSearchEngine


class BrowserAutomation:
    """Main browser automation orchestrator"""
    
    def __init__(self, use_profile=False, headless=False, job_id=None):
        self.use_profile = use_profile
        self.headless = headless
        self.job_id = job_id
        self.cancel_flag = False
        
        # Initialize components
        self.browser_setup = BrowserSetup(use_profile, headless)
        self.driver = None
        self.screenshot_manager = None
        self.search_area_manager = None
        self.search_engine = None

    def is_cancelled(self):
        """Check if automation is cancelled"""
        return self.cancel_flag

    def setup_browser(self):
        """Setup browser and initialize components"""
        try:
            self.driver = self.browser_setup.setup_browser()
            if not self.driver:
                return False
            
            # Initialize component managers
            self.screenshot_manager = ScreenshotManager(self.driver, self.job_id)
            self.search_area_manager = SearchAreaManager(self.driver, self.job_id)
            self.search_engine = MapsSearchEngine(
                self.driver, 
                self.screenshot_manager, 
                self.search_area_manager, 
                self.job_id
            )
            
            return True
        except Exception as e:
            print(f"❌ Error setting up browser automation: {str(e)}")
            return False

    def search_google_maps(self, query, limit=20, min_rating=0.0, min_reviews=0,
                          requires_website=None, recent_review_months=None,
                          min_photos=None, min_description_length=None, 
                          enable_click_through=True, enable_pagespeed=False, max_pagespeed_score=None,
                          max_runtime_minutes=None):
        """Search Google Maps using the search engine"""
        if not self.search_engine:
            print("❌ Browser not properly initialized")
            return []
        
        if self.cancel_flag:
            self.search_engine.set_cancel_flag()
        
        # Pass enable_pagespeed and max_pagespeed_score to the search engine
        self.search_engine.enable_pagespeed = enable_pagespeed
        self.search_engine.max_pagespeed_score = max_pagespeed_score
        
        return self.search_engine.search_google_maps(
            query, limit, min_rating, min_reviews, requires_website,
            recent_review_months, min_photos, min_description_length,
            enable_click_through, max_runtime_minutes
        )

    def close(self):
        """Clean up and close browser"""
        if self.browser_setup:
            self.browser_setup.close()
        print("✅ Browser automation cleanup complete")


# Backward compatibility - maintain the original interface
def save_lead_to_database(business_details, job_id=None, enable_pagespeed=False, max_pagespeed_score=None):
    """Backward compatibility wrapper"""
    from database_operations import save_lead_to_database as db_save
    return db_save(business_details, job_id, enable_pagespeed, max_pagespeed_score)