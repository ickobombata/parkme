from pydantic import BaseModel
from datetime import datetime
from typing import Optional, Dict, Any
from enum import Enum

class LogLevel(str, Enum):
    DEBUG = "debug"
    INFO = "info"
    WARNING = "warning"
    ERROR = "error"
    CRITICAL = "critical"

class LogEntry(BaseModel):
    id: Optional[int] = None
    level: LogLevel
    message: str
    timestamp: datetime
    device_id: Optional[str] = None
    component: Optional[str] = None
    details: Optional[Dict[str, Any]] = None
    
    class Config:
        json_encoders = {
            datetime: lambda v: v.isoformat()
        }

class LogQuery(BaseModel):
    limit: int = 100
    offset: int = 0
    level: Optional[LogLevel] = None
    device_id: Optional[str] = None
    component: Optional[str] = None
    start_time: Optional[datetime] = None
    end_time: Optional[datetime] = None
    search: Optional[str] = None 