"""
Main FastAPI application.
Pattern: Composition Root Pattern - assembles all dependencies.
Single Responsibility: Application configuration and router registration only.
File size: <100 lines as per CLAUDE.md requirements.
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
import logging

from .database import engine, Base
from .routers import (
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

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Application lifecycle management.
    Pattern: Resource Manager Pattern for startup/shutdown.
    """
    logger.info("Starting application...")
    Base.metadata.create_all(bind=engine)
    yield
    logger.info("Shutting down application...")


def create_app() -> FastAPI:
    """
    Factory function to create FastAPI application.
    Pattern: Factory Pattern for application creation.
    """
    app = FastAPI(
        title="LeadLawk API",
        description="Lead generation and management system",
        version="1.0.0",
        lifespan=lifespan
    )
    
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    
    app.include_router(health_router.router)
    app.include_router(leads_router.router)
    app.include_router(jobs_router.router)
    app.include_router(admin_router.router)
    app.include_router(websocket_router.router)
    app.include_router(analytics_router.router)
    app.include_router(sales_router.router)
    app.include_router(misc_router.router)
    app.include_router(pagespeed_router.router)
    app.include_router(conversion_router.router)
    
    @app.get("/")
    async def root():
        """Root endpoint for API discovery."""
        return {
            "name": "LeadLawk API",
            "version": "1.0.0",
            "docs": "/docs",
            "health": "/health"
        }
    
    return app


app = create_app()