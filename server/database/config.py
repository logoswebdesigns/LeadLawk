"""
Database configuration with optimized settings.
Pattern: Configuration Pattern - centralizes database settings.
Single Responsibility: Database configuration management.
"""

import os
from typing import Dict, Any
from dataclasses import dataclass

@dataclass
class DatabaseConfig:
    """Database configuration settings."""
    
    # Connection settings
    database_url: str = os.getenv("DATABASE_URL", "sqlite:///./db/leadloq.db")
    
    # Connection pool settings
    pool_size: int = 20
    max_overflow: int = 40
    pool_timeout: int = 30
    pool_recycle: int = 3600
    pool_pre_ping: bool = True
    
    # Performance settings
    echo: bool = False
    echo_pool: bool = False
    
    # SQLite specific optimizations
    sqlite_pragmas: Dict[str, Any] = None
    
    def __post_init__(self):
        """Initialize SQLite pragmas for performance."""
        if self.sqlite_pragmas is None:
            self.sqlite_pragmas = {
                "journal_mode": "WAL",  # Write-Ahead Logging for better concurrency
                "cache_size": -64000,    # 64MB cache
                "foreign_keys": 1,       # Enable foreign key constraints
                "synchronous": "NORMAL", # Balance between safety and speed
                "temp_store": "MEMORY",  # Use memory for temp tables
                "mmap_size": 268435456,  # 256MB memory-mapped I/O
                "page_size": 4096,       # Optimal page size
                "optimize": True         # Run ANALYZE periodically
            }
    
    def get_engine_kwargs(self) -> Dict[str, Any]:
        """Get SQLAlchemy engine configuration."""
        kwargs = {
            "echo": self.echo,
            "echo_pool": self.echo_pool,
            "pool_size": self.pool_size,
            "max_overflow": self.max_overflow,
            "pool_timeout": self.pool_timeout,
            "pool_recycle": self.pool_recycle,
            "pool_pre_ping": self.pool_pre_ping,
        }
        
        # SQLite specific settings
        if "sqlite" in self.database_url.lower():
            kwargs["connect_args"] = {"check_same_thread": False}
        
        return kwargs
    
    def apply_sqlite_optimizations(self, connection) -> None:
        """Apply SQLite performance optimizations."""
        if "sqlite" not in self.database_url.lower():
            return
            
        for pragma, value in self.sqlite_pragmas.items():
            if pragma == "optimize":
                connection.execute("PRAGMA optimize")
            else:
                connection.execute(f"PRAGMA {pragma} = {value}")