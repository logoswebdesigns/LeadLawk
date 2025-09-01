#!/usr/bin/env python3
"""
Business extraction utilities
"""

import re
from datetime import datetime, timedelta


class BusinessExtractorUtils:
    @staticmethod
    def extract_industry_from_query(query):
        """Extract industry type from search query"""
        query_lower = query.lower()
        
        industry_keywords = {
            'restaurant': ['restaurant', 'dining', 'food', 'cafe', 'bistro', 'eatery'],
            'retail': ['store', 'shop', 'retail', 'boutique', 'market'],
            'automotive': ['auto', 'car', 'mechanic', 'garage', 'automotive'],
            'healthcare': ['doctor', 'clinic', 'medical', 'health', 'dental', 'pharmacy'],
            'fitness': ['gym', 'fitness', 'yoga', 'workout', 'training'],
            'beauty': ['salon', 'spa', 'beauty', 'barber', 'nail'],
            'home_services': ['plumbing', 'electrical', 'hvac', 'roofing', 'cleaning', 'landscaping'],
            'professional': ['law', 'legal', 'accounting', 'consulting', 'insurance'],
            'education': ['school', 'education', 'tutoring', 'learning'],
            'entertainment': ['bar', 'pub', 'entertainment', 'venue', 'theater']
        }
        
        for industry, keywords in industry_keywords.items():
            if any(keyword in query_lower for keyword in keywords):
                return industry
        
        return 'general'

    @staticmethod
    def extract_location_from_query(query):
        """Extract location from search query"""
        # Remove common business type words to isolate location
        business_words = ['restaurant', 'shop', 'store', 'gym', 'salon', 'clinic', 'bar', 'cafe']
        words = query.lower().split()
        location_words = [word for word in words if word not in business_words]
        
        # Look for location indicators
        location_indicators = ['in', 'near', 'around', 'at']
        location_parts = []
        
        capture_location = False
        for word in words:
            if word.lower() in location_indicators:
                capture_location = True
                continue
            if capture_location:
                location_parts.append(word)
        
        if location_parts:
            return ' '.join(location_parts).strip()
        
        # Fallback: assume last words are location
        return ' '.join(location_words[-2:]).strip() if len(location_words) >= 2 else 'Unknown'

    @staticmethod
    def check_recent_reviews_profile(business_element, months_threshold):
        """Check if business has reviews within the specified months threshold"""
        try:
            from selenium.webdriver.common.by import By
            from selenium.webdriver.support.ui import WebDriverWait
            from selenium.webdriver.support import expected_conditions as EC
            from selenium.common.exceptions import TimeoutException, NoSuchElementException
            
            # Look for review timestamps in various formats
            review_selectors = [
                'span[data-value]',  # Review timestamp spans
                '.DU9Pgb span',      # Review date spans
                '[data-review-id] span', # Individual review spans
                'span',  # All spans - might contain review text
                'div'    # Divs that might contain review snippets
            ]
            
            cutoff_date = datetime.now() - timedelta(days=months_threshold * 30)
            found_review_text = False
            
            for selector in review_selectors:
                try:
                    review_elements = business_element.find_elements(By.CSS_SELECTOR, selector)
                    
                    for element in review_elements[:20]:  # Check more elements
                        text = element.get_attribute('data-value') or element.text
                        if text and BusinessExtractorUtils._is_recent_review_text(text, cutoff_date):
                            print(f"    ✅ Found recent review indicator: {text[:50]}")
                            return True
                        elif text and any(word in text.lower() for word in ['review', 'ago', 'month', 'week', 'day']):
                            found_review_text = True
                            
                except (NoSuchElementException, Exception):
                    continue
            
            # IMPORTANT: Default to True (assume recent) if we can't find review dates
            # We only want to filter out businesses if we can definitively prove they have old reviews
            if not found_review_text:
                print(f"    ⚠️ No review dates found in list view - assuming reviews are recent")
                return True  # Default to True when we can't determine
            
            # If we found review text but no recent indicators, it might be old
            print(f"    ⚠️ Found review text but no recent indicators - assuming old reviews")
            return False
            
        except Exception as e:
            print(f"    ❌ Error checking recent reviews: {str(e)}")
            return True  # Default to True on error

    @staticmethod
    def _is_recent_review_text(text, cutoff_date):
        """Check if review text indicates a recent review"""
        if not text:
            return False
            
        text_lower = text.lower()
        
        # Check for relative time indicators
        recent_indicators = [
            'hour', 'hours ago', 'day', 'days ago', 'week', 'weeks ago', 
            'month', 'months ago', 'yesterday', 'today', 'recently',
            'a month ago', 'a week ago', 'a day ago'
        ]
        
        # Quick check for any time indicators
        if any(indicator in text_lower for indicator in recent_indicators):
            # Parse relative time more accurately
            
            # Hours ago - definitely recent
            if 'hour' in text_lower and 'ago' in text_lower:
                return True
                
            # Days ago
            if 'day' in text_lower and 'ago' in text_lower:
                try:
                    # Extract number before "day" or "days"
                    match = re.search(r'(\d+)\s*days?\s*ago', text_lower)
                    if match:
                        days = int(match.group(1))
                        # Convert cutoff_date to days
                        days_threshold = (datetime.now() - cutoff_date).days
                        return days <= days_threshold
                    elif 'a day ago' in text_lower or 'yesterday' in text_lower:
                        return True
                except:
                    return True  # Assume recent on parse error
                    
            # Weeks ago
            elif 'week' in text_lower and 'ago' in text_lower:
                try:
                    match = re.search(r'(\d+)\s*weeks?\s*ago', text_lower)
                    if match:
                        weeks = int(match.group(1))
                        days_threshold = (datetime.now() - cutoff_date).days
                        return (weeks * 7) <= days_threshold
                    elif 'a week ago' in text_lower:
                        return True
                except:
                    return True  # Assume recent on parse error
                    
            # Months ago
            elif 'month' in text_lower and 'ago' in text_lower:
                try:
                    match = re.search(r'(\d+)\s*months?\s*ago', text_lower)
                    if match:
                        months = int(match.group(1))
                        # Get months threshold from cutoff date
                        months_threshold = (datetime.now() - cutoff_date).days / 30
                        return months <= months_threshold
                    elif 'a month ago' in text_lower:
                        # "a month ago" is within any reasonable threshold
                        return True
                except:
                    return True  # Assume recent on parse error
                    
            # Other recent indicators
            elif any(word in text_lower for word in ['today', 'yesterday', 'recently']):
                return True
                
            # If we found time indicators but couldn't parse, assume recent
            return True
        
        # Check for absolute dates (e.g., "Nov 2024", "2024")
        current_year = datetime.now().year
        current_month = datetime.now().month
        
        # Check for year mentions
        for year in [current_year, current_year - 1]:
            if str(year) in text:
                # If it's the current year, definitely recent
                if year == current_year:
                    return True
                # If it's last year, check if it's within threshold
                elif year == current_year - 1:
                    # Check month if available
                    months = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 
                             'jul', 'aug', 'sep', 'oct', 'nov', 'dec']
                    for i, month in enumerate(months, 1):
                        if month in text_lower:
                            # Create a date for that month
                            review_date = datetime(year, i, 1)
                            return review_date >= cutoff_date
                    # If no month found but has last year, check if within threshold
                    # Assume end of year for safety
                    review_date = datetime(year, 12, 31)
                    return review_date >= cutoff_date
            
        return False