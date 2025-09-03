"""
Browser Optimization Configuration for Selenium Chrome
"""

def get_optimized_chrome_options():
    """
    Returns optimized Chrome options for better performance and lower CPU usage
    """
    from selenium.webdriver.chrome.options import Options
    
    chrome_options = Options()
    
    # Performance optimizations
    chrome_options.add_argument('--disable-gpu')  # Disable GPU acceleration
    chrome_options.add_argument('--disable-dev-shm-usage')  # Overcome limited resource problems
    chrome_options.add_argument('--no-sandbox')  # Required for Docker
    chrome_options.add_argument('--disable-setuid-sandbox')
    
    # Reduce CPU usage
    chrome_options.add_argument('--disable-web-security')
    chrome_options.add_argument('--disable-features=VizDisplayCompositor')
    chrome_options.add_argument('--disable-software-rasterizer')
    
    # Memory optimizations
    chrome_options.add_argument('--memory-pressure-off')
    chrome_options.add_argument('--js-flags=--max-old-space-size=2048')  # Limit JS heap
    chrome_options.add_argument('--disable-extensions')
    chrome_options.add_argument('--disable-plugins')
    
    # Disable unnecessary features
    chrome_options.add_argument('--disable-images')  # Don't load images if not needed
    chrome_options.add_argument('--disable-javascript')  # Only if JS not required
    chrome_options.add_argument('--disable-background-timer-throttling')
    chrome_options.add_argument('--disable-backgrounding-occluded-windows')
    chrome_options.add_argument('--disable-renderer-backgrounding')
    chrome_options.add_argument('--disable-features=TranslateUI')
    chrome_options.add_argument('--disable-ipc-flooding-protection')
    
    # Network optimizations
    chrome_options.add_argument('--aggressive-cache-discard')
    chrome_options.add_argument('--disable-background-networking')
    
    # Set window size to reduce rendering
    chrome_options.add_argument('--window-size=1280,720')
    chrome_options.add_argument('--start-maximized')
    
    # Page load strategy
    chrome_options.page_load_strategy = 'eager'  # Don't wait for all resources
    
    # Experimental options for better performance
    prefs = {
        'profile.default_content_setting_values': {
            'images': 2,  # Block images
            'plugins': 2,  # Block plugins
            'popups': 2,  # Block popups
            'geolocation': 2,  # Block location
            'notifications': 2,  # Block notifications
            'media_stream': 2,  # Block media stream
        },
        'profile.managed_default_content_settings': {
            'images': 2
        }
    }
    chrome_options.add_experimental_option('prefs', prefs)
    
    # Additional performance flags
    chrome_options.add_experimental_option('excludeSwitches', ['enable-logging'])
    chrome_options.add_experimental_option('useAutomationExtension', False)
    
    return chrome_options


# Throughput optimization settings
THROUGHPUT_CONFIG = {
    'max_parallel_browsers': 2,  # Optimal for 8 CPU cores
    'batch_size': 10,  # Process leads in batches
    'page_timeout': 30,  # Seconds before timeout
    'implicit_wait': 5,  # Seconds for element wait
    'retry_delay': 2,  # Seconds between retries
    'cpu_throttle_threshold': 80,  # Pause if CPU > 80%
    'memory_threshold_mb': 5000,  # Pause if memory > 5GB
}

def should_throttle():
    """Check if we should throttle based on system resources"""
    import psutil
    
    cpu_percent = psutil.cpu_percent(interval=1)
    memory_mb = psutil.virtual_memory().used / 1024 / 1024
    
    if cpu_percent > THROUGHPUT_CONFIG['cpu_throttle_threshold']:
        return True, f"CPU usage high: {cpu_percent}%"
    
    if memory_mb > THROUGHPUT_CONFIG['memory_threshold_mb']:
        return True, f"Memory usage high: {memory_mb:.0f}MB"
    
    return False, "Resources OK"