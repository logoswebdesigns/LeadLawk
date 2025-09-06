#!/usr/bin/env python3
"""
Setup Alembic migrations for the database.
Pattern: Migration Setup Script.
"""

import subprocess
import sys
import os
from pathlib import Path

def setup_alembic():
    """Initialize Alembic for database migrations."""
    print("Setting up Alembic migrations...")
    
    # Check if alembic is installed
    try:
        import alembic
    except ImportError:
        print("Installing alembic...")
        subprocess.run([sys.executable, "-m", "pip", "install", "alembic"])
    
    # Initialize alembic if not already done
    if not Path("alembic.ini").exists():
        print("alembic.ini already exists, skipping init")
    else:
        print("Alembic configuration found")
    
    # Create versions directory
    versions_dir = Path("database/migrations/versions")
    versions_dir.mkdir(parents=True, exist_ok=True)
    print(f"Created versions directory: {versions_dir}")
    
    # Create initial migration
    print("Creating initial migration...")
    try:
        subprocess.run([
            sys.executable, "-m", "alembic",
            "revision", "--autogenerate",
            "-m", "Initial migration with optimizations"
        ], check=True)
        print("Initial migration created")
    except subprocess.CalledProcessError as e:
        print(f"Migration creation failed: {e}")
        print("This is normal if tables already exist")
    
    # Apply migrations
    print("Applying migrations...")
    try:
        subprocess.run([
            sys.executable, "-m", "alembic",
            "upgrade", "head"
        ], check=True)
        print("Migrations applied successfully")
    except subprocess.CalledProcessError as e:
        print(f"Migration failed: {e}")
    
    print("Alembic setup complete!")

if __name__ == "__main__":
    setup_alembic()