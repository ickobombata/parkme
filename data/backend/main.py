from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from datetime import datetime
from typing import List, Optional
import json
import os
import asyncio
import logging
from contextlib import asynccontextmanager

# Import our modules
from models.device import Device, DeviceStatus, SensorReading
from models.log import LogEntry, LogLevel
from services.mixed_communication_service import MixedCommunicationService
from services.database_service import DatabaseService
from services.device_service import DeviceService
from services.config_service import config

# Configure logging
log_level = config.get('system.log_level', 'INFO')
logging.basicConfig(level=getattr(logging, log_level))
logger = logging.getLogger(__name__)

# Global services
communication_service = None
db_service = None
device_service = None

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    global communication_service, db_service, device_service
    
    # Initialize database service
    db_config = config.get_database_config()
    db_service = DatabaseService(db_config.get('path', 'data/iot_system.db'))
    await db_service.initialize()
    
    # Initialize mixed communication service
    logger.info("Initializing mixed communication service")
    communication_service = MixedCommunicationService()
    await communication_service.initialize()
    
    # Initialize device service
    device_service = DeviceService(db_service, communication_service)
    await device_service.initialize()
    
    logger.info("Application started successfully with mixed communication support")
    yield
    
    # Shutdown
    if communication_service:
        await communication_service.disconnect()
    if db_service:
        await db_service.close()
    logger.info("Application shutdown complete")

app = FastAPI(
    title="IoT Home Automation API",
    description="Backend API for home IoT device management",
    version="1.0.0",
    lifespan=lifespan
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify your domain
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Pydantic models for API
class WaterCommand(BaseModel):
    duration: int = 5  # seconds
    device_id: str = "arduino_pump"

class SystemStatus(BaseModel):
    status: str
    devices: List[Device]
    last_updated: datetime

class ApiResponse(BaseModel):
    success: bool
    message: str
    data: Optional[dict] = None

# Health check endpoint
@app.get("/health")
async def health_check():
    return {"status": "healthy", "timestamp": datetime.now()}

# System status endpoint
@app.get("/api/status", response_model=SystemStatus)
async def get_system_status():
    try:
        devices = await device_service.get_all_devices()
        return SystemStatus(
            status="online",
            devices=devices,
            last_updated=datetime.now()
        )
    except Exception as e:
        logger.error(f"Error getting system status: {e}")
        raise HTTPException(status_code=500, detail="Failed to get system status")

# Device endpoints
@app.get("/api/devices", response_model=List[Device])
async def get_devices():
    try:
        return await device_service.get_all_devices()
    except Exception as e:
        logger.error(f"Error getting devices: {e}")
        raise HTTPException(status_code=500, detail="Failed to get devices")

@app.get("/api/devices/{device_id}", response_model=Device)
async def get_device(device_id: str):
    try:
        device = await device_service.get_device(device_id)
        if not device:
            raise HTTPException(status_code=404, detail="Device not found")
        return device
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting device {device_id}: {e}")
        raise HTTPException(status_code=500, detail="Failed to get device")

# Water control endpoints
@app.post("/api/water/start", response_model=ApiResponse)
async def start_watering(command: WaterCommand):
    try:
        success = await device_service.send_command(
            command.device_id,
            "water_start",
            {"duration": command.duration}
        )
        
        if success:
            # Log the action
            await db_service.add_log(LogEntry(
                level=LogLevel.INFO,
                message=f"Watering started for {command.duration} seconds",
                device_id=command.device_id,
                timestamp=datetime.now()
            ))
            
            return ApiResponse(
                success=True,
                message=f"Watering started for {command.duration} seconds",
                data={"duration": command.duration, "device_id": command.device_id}
            )
        else:
            raise HTTPException(status_code=500, detail="Failed to start watering")
            
    except Exception as e:
        logger.error(f"Error starting watering: {e}")
        raise HTTPException(status_code=500, detail="Failed to start watering")

@app.post("/api/water/stop", response_model=ApiResponse)
async def stop_watering(device_id: str = "arduino_pump"):
    try:
        success = await device_service.send_command(device_id, "water_stop", {})
        
        if success:
            await db_service.add_log(LogEntry(
                level=LogLevel.INFO,
                message="Watering stopped manually",
                device_id=device_id,
                timestamp=datetime.now()
            ))
            
            return ApiResponse(
                success=True,
                message="Watering stopped",
                data={"device_id": device_id}
            )
        else:
            raise HTTPException(status_code=500, detail="Failed to stop watering")
            
    except Exception as e:
        logger.error(f"Error stopping watering: {e}")
        raise HTTPException(status_code=500, detail="Failed to stop watering")

# Sensor data endpoints
@app.get("/api/sensors/{device_id}/latest", response_model=List[SensorReading])
async def get_latest_sensor_data(device_id: str):
    try:
        readings = await device_service.get_latest_sensor_readings(device_id)
        return readings
    except Exception as e:
        logger.error(f"Error getting sensor data for {device_id}: {e}")
        raise HTTPException(status_code=500, detail="Failed to get sensor data")

@app.get("/api/sensors/{device_id}/history")
async def get_sensor_history(device_id: str, hours: int = 24):
    try:
        readings = await device_service.get_sensor_history(device_id, hours)
        return readings
    except Exception as e:
        logger.error(f"Error getting sensor history for {device_id}: {e}")
        raise HTTPException(status_code=500, detail="Failed to get sensor history")

# Logs endpoints
@app.get("/api/logs", response_model=List[LogEntry])
async def get_logs(limit: int = 100, device_id: Optional[str] = None):
    try:
        logs = await db_service.get_logs(limit=limit, device_id=device_id)
        return logs
    except Exception as e:
        logger.error(f"Error getting logs: {e}")
        raise HTTPException(status_code=500, detail="Failed to get logs")

# Configuration endpoints
@app.get("/api/config")
async def get_config():
    try:
        config = await device_service.get_system_config()
        return config
    except Exception as e:
        logger.error(f"Error getting config: {e}")
        raise HTTPException(status_code=500, detail="Failed to get config")

@app.post("/api/config")
async def update_config(config: dict):
    try:
        await device_service.update_system_config(config)
        return ApiResponse(success=True, message="Configuration updated")
    except Exception as e:
        logger.error(f"Error updating config: {e}")
        raise HTTPException(status_code=500, detail="Failed to update config")

# WebSocket endpoint for real-time updates
@app.websocket("/ws")
async def websocket_endpoint(websocket):
    await websocket.accept()
    try:
        while True:
            # Send periodic updates
            status = await get_system_status()
            await websocket.send_json(status.dict())
            await asyncio.sleep(5)  # Update every 5 seconds
    except Exception as e:
        logger.error(f"WebSocket error: {e}")
    finally:
        await websocket.close()

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000) 