"""Authentication middleware.
Pattern: Chain of Responsibility.
Single Responsibility: Verify auth tokens.
"""

from typing import Optional, List
from fastapi import Request, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from functools import wraps

from .models import UserRole, TokenData
from .jwt_service import JWTService


class AuthBearer(HTTPBearer):
    """JWT Bearer token authentication."""
    
    def __init__(self, auto_error: bool = True):
        super().__init__(auto_error=auto_error)
    
    async def __call__(self, request: Request) -> Optional[TokenData]:
        credentials: HTTPAuthorizationCredentials = await super().__call__(request)
        
        if not credentials:
            if self.auto_error:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Invalid authentication credentials"
                )
            return None
        
        if credentials.scheme != "Bearer":
            if self.auto_error:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Invalid authentication scheme"
                )
            return None
        
        token_data = await self.verify_token(credentials.credentials)
        
        if not token_data:
            if self.auto_error:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Invalid or expired token"
                )
            return None
        
        # Store user info in request state
        request.state.user_id = token_data.sub
        request.state.user_email = token_data.email
        request.state.user_role = token_data.role
        
        return token_data
    
    async def verify_token(self, token: str) -> Optional[TokenData]:
        """Verify JWT token."""
        return JWTService.verify_access_token(token)


def require_auth(bearer: AuthBearer = AuthBearer()):
    """Decorator to require authentication."""
    def decorator(func):
        @wraps(func)
        async def wrapper(*args, **kwargs):
            # Auth is handled by dependency injection
            return await func(*args, **kwargs)
        return wrapper
    return decorator


def require_roles(allowed_roles: List[UserRole]):
    """Decorator to require specific roles."""
    def decorator(func):
        @wraps(func)
        async def wrapper(request: Request, *args, **kwargs):
            # Check if user has required role
            user_role = getattr(request.state, 'user_role', None)
            
            if not user_role:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Authentication required"
                )
            
            if user_role not in allowed_roles:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail=f"Insufficient permissions. Required roles: {allowed_roles}"
                )
            
            return await func(request, *args, **kwargs)
        return wrapper
    return decorator


class RoleChecker:
    """Role-based access control dependency."""
    
    def __init__(self, allowed_roles: List[UserRole]):
        self.allowed_roles = allowed_roles
    
    def __call__(self, token_data: TokenData = AuthBearer()) -> TokenData:
        if token_data.role not in self.allowed_roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Insufficient permissions. Required roles: {self.allowed_roles}"
            )
        return token_data


# Convenience role checkers
require_admin = RoleChecker([UserRole.ADMIN])
require_manager = RoleChecker([UserRole.ADMIN, UserRole.MANAGER])
require_agent = RoleChecker([UserRole.ADMIN, UserRole.MANAGER, UserRole.AGENT])