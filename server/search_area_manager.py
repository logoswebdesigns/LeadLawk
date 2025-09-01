#!/usr/bin/env python3
"""
Search area expansion and management utilities
"""

import re
import time
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.action_chains import ActionChains
from selenium.common.exceptions import TimeoutException, NoSuchElementException
from job_management import add_job_log


class SearchAreaManager:
    def __init__(self, driver, job_id=None):
        self.driver = driver
        self.job_id = job_id
    
    def _log(self, message):
        """Log message to both console and job logs for WebSocket"""
        print(message)  # Keep console output for debugging
        if self.job_id:
            add_job_log(self.job_id, message)

    def expand_search_area(self, expansion_number, evaluated_businesses, original_query=None):
        """Expand the search area by modifying query, zooming out, and submitting with Enter"""
        try:
            self._log(f"\n🗺️ Attempting search area expansion #{expansion_number}")
            self._log(f"    📊 Already evaluated {len(evaluated_businesses)} businesses")
            
            # Step 1: Modify the search query to remove location
            if original_query:
                modified_query = self._remove_location_from_query(original_query, expansion_number)
                self._log(f"    📝 Modified query: '{original_query}' → '{modified_query}'")
                
                # Update the search box with the modified query
                if not self._update_search_query(modified_query):
                    self._log(f"    ⚠️ Could not update search query, proceeding with current query")
            
            # Step 2: Zoom out to expand the visible area
            self._log(f"    🔍 Zooming out map (expansion #{expansion_number})...")
            zoom_out_successful = self._perform_zoom_out(expansion_number)
            
            if not zoom_out_successful:
                self._log(f"    ⚠️ Could not zoom out, but continuing with Enter key submission")
            
            # Wait for map to update
            time.sleep(2)
            
            # Step 3: Submit search with Enter/Return key instead of clicking button
            return self._submit_search_with_enter()
            
        except Exception as e:
            self._log(f"    ❌ Error in search area expansion #{expansion_number}: {str(e)}")
            return False

    def _perform_zoom_out(self, expansion_number):
        """Perform zoom out operation using multiple methods"""
        try:
            # Calculate zoom steps for controlled expansion
            if expansion_number == 1:
                zoom_steps = 1
            elif expansion_number == 2:
                zoom_steps = 1
            else:
                zoom_steps = 1
            
            self._log(f"    📏 Using {zoom_steps} zoom steps for controlled expansion #{expansion_number}")
            
            # Method 1: Use keyboard shortcut (most reliable)
            if self._zoom_out_with_keyboard(zoom_steps):
                return True
                
            # Method 2: Look for zoom out button
            if self._zoom_out_with_button(zoom_steps):
                return True
                
            # Method 3: JavaScript zoom out (fallback)
            if self._zoom_out_with_javascript(zoom_steps):
                return True
                
            return False
            
        except Exception as e:
            self._log(f"    ❌ Error performing zoom out: {str(e)}")
            return False

    def _zoom_out_with_keyboard(self, zoom_steps):
        """Zoom out using keyboard shortcuts"""
        try:
            actions = ActionChains(self.driver)
            
            # Try multiple selectors for the map element
            map_selectors = [
                "#map",  # Original selector
                ".widget-scene-canvas",  # Google Maps canvas
                "div[data-value='Map']",  # Map container
                ".maps-container",  # Alternative container
                "body"  # Fallback to body
            ]
            
            map_element = None
            for selector in map_selectors:
                try:
                    map_element = self.driver.find_element(By.CSS_SELECTOR, selector)
                    break
                except:
                    continue
            
            if not map_element:
                self._log(f"    ❌ Could not find map element for keyboard zoom")
                return False
            
            actions.click(map_element)
            actions.send_keys('-')
            time.sleep(0.5)
            actions.perform()
            
            self._log(f"    ✅ Zoomed out {zoom_steps} steps using keyboard")
            return True
        except Exception as e:
            self._log(f"    ❌ Keyboard zoom out failed: {str(e)}")
            return False

    def _zoom_out_with_button(self, zoom_steps):
        """Zoom out using UI buttons"""
        try:
            zoom_out_selectors = [
                "button[aria-label*='Zoom out']",
                "button[title*='Zoom out']",
                ".widget-zoom-out",
                "div[data-value='zoom_out']"
            ]
            
            for selector in zoom_out_selectors:
                try:
                    zoom_button = self.driver.find_element(By.CSS_SELECTOR, selector)
                    self.driver.execute_script("arguments[0].click();", zoom_button)
                    time.sleep(0.5)
                    self._log(f"    ✅ Zoomed out {zoom_steps} times using button: {selector}")
                    return True
                except:
                    continue
                    
            return False
        except Exception as e:
            self._log(f"    ❌ Button zoom out failed: {str(e)}")
            return False

    def _zoom_out_with_javascript(self, zoom_steps):
        """Zoom out using JavaScript wheel events"""
        try:
            self.driver.execute_script(f"""
                // Try multiple selectors for the map element
                var mapSelectors = ['#map', '.widget-scene-canvas', 'div[data-value="Map"]', '.maps-container'];
                var mapElement = null;
                
                for (var i = 0; i < mapSelectors.length; i++) {{
                    mapElement = document.querySelector(mapSelectors[i]);
                    if (mapElement) break;
                }}
                
                // Fallback to document body if no map element found
                if (!mapElement) {{
                    mapElement = document.body;
                }}
                
                if (mapElement) {{
                    for (let i = 0; i < {zoom_steps}; i++) {{
                        var event = new WheelEvent('wheel', {{
                            deltaY: 40,
                            bubbles: true,
                            cancelable: true
                        }});
                        mapElement.dispatchEvent(event);
                        if (i < {zoom_steps - 1}) {{
                            setTimeout(function() {{}}, 150);
                        }}
                    }}
                }}
            """)
            self._log(f"    ✅ Zoomed out {zoom_steps} steps using JavaScript")
            return True
        except Exception as e:
            self._log(f"    ❌ JavaScript zoom out failed: {str(e)}")
            return False

    def _remove_location_from_query(self, original_query, expansion_number):
        """Remove location from search query for broader search"""
        try:
            # Common location patterns to remove
            location_patterns = [
                r'\s+in\s+[^,]+(?:,\s*[^,]+)*$',  # "in City, State" at end
                r'\s+near\s+[^,]+(?:,\s*[^,]+)*$',  # "near City, State" at end  
                r',\s*[^,]+(?:,\s*[^,]+)*$',  # ", City, State" at end
                r'\s+[A-Z][a-z]+(?:,\s*[A-Z]{2})?$',  # "CityName" or "CityName, ST" at end
            ]
            
            import re
            modified_query = original_query
            
            for pattern in location_patterns:
                new_query = re.sub(pattern, '', modified_query, flags=re.IGNORECASE).strip()
                if new_query and new_query != modified_query:
                    modified_query = new_query
                    break
            
            # If no location was removed, just return the original query
            if modified_query == original_query:
                self._log(f"    📍 No location pattern found to remove from: '{original_query}'")
                return original_query
            
            return modified_query
            
        except Exception as e:
            self._log(f"    ❌ Error modifying query: {str(e)}")
            return original_query

    def _update_search_query(self, new_query):
        """Update the search box with modified query"""
        try:
            # Find the search input box
            search_selectors = [
                "#searchboxinput",
                "input[role='combobox']",
                "input[aria-label*='Search']",
                ".searchbox input"
            ]
            
            for selector in search_selectors:
                try:
                    search_box = self.driver.find_element(By.CSS_SELECTOR, selector)
                    search_box.clear()
                    search_box.send_keys(new_query)
                    self._log(f"    ✅ Updated search query to: '{new_query}'")
                    return True
                except:
                    continue
            
            self._log(f"    ❌ Could not find search input box")
            return False
            
        except Exception as e:
            self._log(f"    ❌ Error updating search query: {str(e)}")
            return False

    def _submit_search_with_enter(self):
        """Submit the search using Enter/Return key instead of clicking button"""
        try:
            from selenium.webdriver.common.keys import Keys
            
            self._log(f"    ⌨️ Submitting search with Enter key...")
            
            # Find the search input box and submit with Enter
            search_selectors = [
                "#searchboxinput",
                "input[role='combobox']", 
                "input[aria-label*='Search']",
                ".searchbox input"
            ]
            
            for selector in search_selectors:
                try:
                    search_box = self.driver.find_element(By.CSS_SELECTOR, selector)
                    search_box.send_keys(Keys.RETURN)
                    self._log(f"    ✅ Successfully submitted search with Enter key using: {selector}")
                    
                    # Wait for results to load
                    self._log(f"    ⏳ Waiting for new results to load...")
                    time.sleep(3)
                    
                    return True
                except:
                    continue
            
            self._log(f"    ❌ Could not find search input box to submit with Enter")
            return False
            
        except Exception as e:
            self._log(f"    ❌ Error submitting search with Enter: {str(e)}")
            return False

    def scroll_results_panel(self):
        """Scroll the results panel to load more businesses"""
        try:
            # More specific selectors for Google Maps results panel
            scroll_selectors = [
                # Main results container (most common)
                'div[role="main"]',
                # Search results panel
                '.m6QErb[data-value="Search results"]',
                'div[data-value="Search results"]',
                # Alternative containers
                '.section-scrollbox',
                '.scrollable-y',
                # Try the parent container of business elements
                '.Nv2PK',  # Parent of individual business cards
                '.section-result',
                # More generic fallbacks
                '[data-value*="results"]',
                '[role="region"]'
            ]
            
            # First, try to find the container that actually contains our business elements
            business_container = None
            try:
                # Look for a business element to trace back to its scrollable parent
                business_element = self.driver.find_element(By.CSS_SELECTOR, 'a.hfpxzc[aria-label][href*="/maps/place/"]')
                current = business_element
                
                # Walk up the DOM to find the scrollable container
                for _ in range(10):  # Max 10 levels up
                    current = self.driver.execute_script("return arguments[0].parentElement;", current)
                    if not current:
                        break
                    
                    # Check if this element is scrollable
                    overflow_y = self.driver.execute_script("return window.getComputedStyle(arguments[0]).overflowY;", current)
                    scroll_height = self.driver.execute_script("return arguments[0].scrollHeight;", current)
                    client_height = self.driver.execute_script("return arguments[0].clientHeight;", current)
                    
                    if overflow_y in ['auto', 'scroll'] and scroll_height > client_height:
                        business_container = current
                        self._log(f"    📍 Found scrollable container via business element tracing")
                        break
            except:
                pass
            
            # If we found a container via business element, use that
            containers_to_try = [business_container] if business_container else []
            
            # Add our predefined selectors as fallbacks
            for selector in scroll_selectors:
                try:
                    container = self.driver.find_element(By.CSS_SELECTOR, selector)
                    containers_to_try.append(container)
                except:
                    continue
            
            # Try each container
            for container in containers_to_try:
                if not container:
                    continue
                    
                try:
                    # Get current scroll position
                    current_scroll = self.driver.execute_script("return arguments[0].scrollTop;", container)
                    scroll_height = self.driver.execute_script("return arguments[0].scrollHeight;", container)
                    client_height = self.driver.execute_script("return arguments[0].clientHeight;", container)
                    
                    self._log(f"    📏 Container: scrollTop={current_scroll}, scrollHeight={scroll_height}, clientHeight={client_height}")
                    
                    # Skip if not scrollable or already at bottom
                    if scroll_height <= client_height:
                        self._log(f"    ⏭️ Container not scrollable (height {scroll_height} <= client {client_height})")
                        continue
                    
                    if current_scroll >= scroll_height - client_height - 50:
                        self._log(f"    ⏭️ Already at bottom of container")
                        continue
                    
                    # Scroll incrementally (by about 2-3 business cards worth)
                    increment = 600  # Reduced increment for more controlled scrolling
                    new_scroll_position = min(current_scroll + increment, scroll_height - client_height)
                    
                    self._log(f"    🔽 Scrolling from {current_scroll} to {new_scroll_position}")
                    
                    # Use simple scrollTop for more reliable scrolling
                    self.driver.execute_script(f"""
                        arguments[0].scrollTop = {new_scroll_position};
                    """, container)
                    
                    # Wait for new content to load
                    time.sleep(3)  # Increased wait time
                    
                    # Check if scroll actually happened
                    new_scroll = self.driver.execute_script("return arguments[0].scrollTop;", container)
                    self._log(f"    ✅ Scroll completed: now at {new_scroll}")
                    
                    # If we're near the bottom, try to load more
                    if new_scroll >= scroll_height - client_height - 100:
                        self._log("    📜 Near bottom, attempting to trigger more loading...")
                        # Send Page Down key to trigger more results
                        from selenium.webdriver.common.keys import Keys
                        container.send_keys(Keys.PAGE_DOWN)
                        time.sleep(2)
                    
                    return True
                    
                except Exception as inner_e:
                    self._log(f"    ❌ Failed to scroll container: {str(inner_e)[:100]}")
                    continue
            
            self._log("    ❌ No suitable scrollable container found")
            return False
            
        except Exception as e:
            self._log(f"    ❌ Error scrolling results panel: {str(e)}")
            return False