from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, DeclarativeBase

import config

engine = create_engine(config.require("DATABASE_URL"), pool_pre_ping=True)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


class Base(DeclarativeBase):
    pass


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
