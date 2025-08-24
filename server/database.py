from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from pathlib import Path

Path("db").mkdir(exist_ok=True)

SQLALCHEMY_DATABASE_URL = "sqlite:///./db/leadlawk.db"

engine = create_engine(
    SQLALCHEMY_DATABASE_URL, 
    connect_args={"check_same_thread": False}
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()

def init_db():
    from models import Lead, CallLog
    Base.metadata.create_all(bind=engine)