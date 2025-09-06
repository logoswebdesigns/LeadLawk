"""
Router module initialization.
Following the Router Pattern from FastAPI best practices.
Each router handles a specific domain concern.
"""

from . import (
    auth_router,
    health_router, 
    leads_router,
    jobs_router,
    admin_router,
    websocket_router,
    analytics_router,
    sales_router,
    misc_router,
    pagespeed_router,
    conversion_router
)

__all__ = [
    "auth_router",
    "health_router", 
    "leads_router",
    "jobs_router",
    "admin_router",
    "websocket_router",
    "analytics_router",
    "sales_router",
    "misc_router",
    "pagespeed_router",
    "conversion_router"
]