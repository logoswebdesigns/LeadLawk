"""Rate limiting for API endpoints.
Pattern: Token Bucket Algorithm.
Single Responsibility: Rate limit requests.
"""

from typing import Dict, Optional
from datetime import datetime, timedelta
from fastapi import Request, HTTPException, status
import time
from collections import defaultdict
import asyncio

from .models import UserRole


class RateLimiter:
    """Token bucket rate limiter."""
    
    def __init__(
        self,
        requests_per_minute: int = 60,
        burst_size: Optional[int] = None
    ):
        self.requests_per_minute = requests_per_minute
        self.burst_size = burst_size or requests_per_minute
        self.buckets: Dict[str, TokenBucket] = {}
        self._lock = asyncio.Lock()
    
    async def check_rate_limit(self, identifier: str) -> bool:
        """Check if request is allowed."""
        async with self._lock:
            if identifier not in self.buckets:
                self.buckets[identifier] = TokenBucket(
                    capacity=self.burst_size,
                    refill_rate=self.requests_per_minute / 60.0
                )
            
            bucket = self.buckets[identifier]
            return bucket.consume()
    
    async def __call__(self, request: Request) -> None:
        """Middleware callable."""
        # Get identifier (IP or user ID)
        identifier = self._get_identifier(request)
        
        if not await self.check_rate_limit(identifier):
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="Rate limit exceeded. Please try again later.",
                headers={"Retry-After": "60"}
            )
    
    def _get_identifier(self, request: Request) -> str:
        """Get rate limit identifier from request."""
        # Prefer user ID if authenticated
        if hasattr(request.state, 'user_id'):
            return f"user:{request.state.user_id}"
        
        # Fall back to IP address
        client_ip = request.client.host if request.client else "unknown"
        return f"ip:{client_ip}"


class TokenBucket:
    """Token bucket for rate limiting."""
    
    def __init__(self, capacity: int, refill_rate: float):
        self.capacity = capacity
        self.refill_rate = refill_rate
        self.tokens = capacity
        self.last_refill = time.time()
    
    def consume(self, tokens: int = 1) -> bool:
        """Try to consume tokens."""
        self._refill()
        
        if self.tokens >= tokens:
            self.tokens -= tokens
            return True
        return False
    
    def _refill(self):
        """Refill tokens based on elapsed time."""
        now = time.time()
        elapsed = now - self.last_refill
        
        tokens_to_add = elapsed * self.refill_rate
        self.tokens = min(self.capacity, self.tokens + tokens_to_add)
        self.last_refill = now


class RoleBasedRateLimiter:
    """Rate limiter with different limits per role."""
    
    # Rate limits per role (requests per minute)
    ROLE_LIMITS = {
        UserRole.ADMIN: 300,
        UserRole.MANAGER: 200,
        UserRole.AGENT: 100,
        UserRole.VIEWER: 60,
    }
    
    def __init__(self):
        self.limiters = {
            role: RateLimiter(limit)
            for role, limit in self.ROLE_LIMITS.items()
        }
        self.default_limiter = RateLimiter(30)  # For unauthenticated
    
    async def __call__(self, request: Request) -> None:
        """Check rate limit based on user role."""
        user_role = getattr(request.state, 'user_role', None)
        
        if user_role and user_role in self.limiters:
            limiter = self.limiters[user_role]
        else:
            limiter = self.default_limiter
        
        await limiter(request)


# Global rate limiter instances
default_rate_limiter = RateLimiter(60)
strict_rate_limiter = RateLimiter(10)
role_based_limiter = RoleBasedRateLimiter()