#!/usr/bin/env python3
"""
Screenshot management utilities
"""

import os
import time
from pathlib import Path
from datetime import datetime
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.common.exceptions import TimeoutException


class ScreenshotManager:
    def __init__(self, driver, job_id=None):
        self.driver = driver
        self.job_id = job_id
        self.screenshots_dir = Path("screenshots")
        self.screenshots_dir.mkdir(exist_ok=True)

    def take_screenshot(self, description="screenshot", log_to_job=True):
        """Take a screenshot with timestamp and description"""
        try:
            timestamp = datetime.now().strftime("%H%M%S")
            if self.job_id:
                filename = f"job_{self.job_id}_{timestamp}_{description}.png"
            else:
                filename = f"{timestamp}_{description}.png"
            
            filepath = self.screenshots_dir / filename
            
            # Don't cleanup business screenshots - only cleanup non-business screenshots
            if not description.startswith("business_"):
                # Clean up old non-business screenshots for this job (keep max 3)
                self._cleanup_old_screenshots(exclude_business=True)
            
            success = self.driver.save_screenshot(str(filepath))
            if success:
                if log_to_job:
                    print(f"    📸 Screenshot saved: {filename}")
                return filename
            else:
                print(f"    ❌ Failed to save screenshot: {filename}")
                return None
        except Exception as e:
            print(f"    ❌ Error taking screenshot: {str(e)}")
            return None

    def take_business_screenshot(self, business_name, business_element=None):
        """Take a screenshot focused on a specific business with highlighting"""
        try:
            if business_element:
                print(f"    🎯 Focusing on business element for screenshot")
                
                # Scroll element into view
                self.driver.execute_script(
                    "arguments[0].scrollIntoView({behavior: 'smooth', block: 'center'});",
                    business_element
                )
                time.sleep(0.5)
                
                # Get original style to restore later
                original_style = business_element.get_attribute('style')
                
                # Add temporary highlight to make the business more visible
                self.driver.execute_script("""
                    arguments[0].style.border = '3px solid #ff6b35';
                    arguments[0].style.borderRadius = '8px';
                    arguments[0].style.boxShadow = '0 0 15px rgba(255, 107, 53, 0.5)';
                    arguments[0].style.backgroundColor = 'rgba(255, 107, 53, 0.1)';
                """, business_element)
                
                time.sleep(0.5)  # Brief pause to ensure highlight is applied
            
            # Clean business name for filename
            clean_name = ''.join(c for c in business_name if c.isalnum() or c in (' ', '-', '_')).strip()
            clean_name = clean_name.replace(' ', '_').lower()
            
            timestamp = datetime.now().strftime("%H%M%S")
            description = f"business_{clean_name}_{timestamp}"
            
            # Take the screenshot with highlight
            filename = self.take_screenshot(description, log_to_job=True)
            
            # Remove the highlight
            if business_element:
                try:
                    if original_style:
                        self.driver.execute_script("arguments[0].setAttribute('style', arguments[1]);", business_element, original_style)
                    else:
                        self.driver.execute_script("arguments[0].removeAttribute('style');", business_element)
                except Exception as restore_error:
                    print(f"    ⚠️ Could not restore original element style: {restore_error}")
            
            if filename:
                print(f"    📸 Business screenshot saved: {business_name} -> {filename}")
                return filename
            else:
                print(f"    ❌ Failed to save business screenshot for: {business_name}")
                return None
                
        except Exception as e:
            print(f"    ❌ Error taking business screenshot for {business_name}: {str(e)}")
            return None

    def _cleanup_old_screenshots(self, max_screenshots=3, exclude_business=False):
        """Clean up old screenshots to prevent disk space issues"""
        try:
            if not self.job_id:
                return
                
            job_screenshots = []
            for file in self.screenshots_dir.glob(f"job_{self.job_id}_*.png"):
                if exclude_business and "_business_" in file.name:
                    continue
                job_screenshots.append(file)
            
            # Sort by creation time, oldest first
            job_screenshots.sort(key=lambda x: x.stat().st_mtime)
            
            # Keep only the most recent max_screenshots
            if len(job_screenshots) > max_screenshots:
                files_to_delete = job_screenshots[:-max_screenshots]
                for file in files_to_delete:
                    try:
                        os.remove(file)
                        print(f"    🗑️ Cleaned up old screenshot: {file.name}")
                    except Exception as e:
                        print(f"    ❌ Error deleting screenshot {file.name}: {str(e)}")
        except Exception as e:
            print(f"    ❌ Error during screenshot cleanup: {str(e)}")