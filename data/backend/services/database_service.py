import sqlite3
import aiosqlite
import asyncio
import logging
from datetime import datetime, timedelta
from typing import List, Optional, Dict, Any
from models.device import Device, DeviceStatus, SensorReading, DeviceType, SensorType
from models.log import LogEntry, LogLevel

logger = logging.getLogger(__name__)

class DatabaseService:
    def __init__(self, db_path: str = "data/iot_system.db"):
        self.db_path = db_path
        self.connection = None
        
    async def initialize(self):
        """Initialize database and create tables"""
        try:
            # Create tables
            await self._create_tables()
            logger.info("Database initialized successfully")
        except Exception as e:
            logger.error(f"Error initializing database: {e}")
            raise
    
    async def _create_tables(self):
        """Create all required tables"""
        async with aiosqlite.connect(self.db_path) as db:
            # Devices table
            await db.execute('''
                CREATE TABLE IF NOT EXISTS devices (
                    id TEXT PRIMARY KEY,
                    name TEXT NOT NULL,
                    device_type TEXT NOT NULL,
                    status TEXT NOT NULL,
                    ip_address TEXT,
                    last_seen TIMESTAMP,
                    location TEXT,
                    description TEXT,
                    firmware_version TEXT,
                    battery_level INTEGER,
                    is_active BOOLEAN DEFAULT 1,
                    config TEXT,
                    capabilities TEXT,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            ''')
            
            # Sensor readings table
            await db.execute('''
                CREATE TABLE IF NOT EXISTS sensor_readings (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    device_id TEXT NOT NULL,
                    sensor_type TEXT NOT NULL,
                    value REAL NOT NULL,
                    unit TEXT NOT NULL,
                    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (device_id) REFERENCES devices (id)
                )
            ''')
            
            # System logs table
            await db.execute('''
                CREATE TABLE IF NOT EXISTS system_logs (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    level TEXT NOT NULL,
                    message TEXT NOT NULL,
                    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    device_id TEXT,
                    component TEXT,
                    details TEXT,
                    FOREIGN KEY (device_id) REFERENCES devices (id)
                )
            ''')
            
            # Device commands table
            await db.execute('''
                CREATE TABLE IF NOT EXISTS device_commands (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    device_id TEXT NOT NULL,
                    command TEXT NOT NULL,
                    parameters TEXT,
                    success BOOLEAN,
                    response TEXT,
                    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (device_id) REFERENCES devices (id)
                )
            ''')
            
            # System configuration table
            await db.execute('''
                CREATE TABLE IF NOT EXISTS system_config (
                    key TEXT PRIMARY KEY,
                    value TEXT NOT NULL,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            ''')
            
            # Create indexes for better performance
            await db.execute('CREATE INDEX IF NOT EXISTS idx_sensor_readings_device_timestamp ON sensor_readings(device_id, timestamp)')
            await db.execute('CREATE INDEX IF NOT EXISTS idx_system_logs_timestamp ON system_logs(timestamp)')
            await db.execute('CREATE INDEX IF NOT EXISTS idx_device_commands_device_timestamp ON device_commands(device_id, timestamp)')
            
            await db.commit()
            logger.info("Database tables created successfully")
    
    async def close(self):
        """Close database connection"""
        if self.connection:
            await self.connection.close()
            logger.info("Database connection closed")
    
    # Device operations
    async def add_device(self, device: Device):
        """Add or update device in database"""
        async with aiosqlite.connect(self.db_path) as db:
            await db.execute('''
                INSERT OR REPLACE INTO devices 
                (id, name, device_type, status, ip_address, last_seen, location, 
                 description, firmware_version, battery_level, is_active, config, capabilities, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', (
                device.id, device.name, device.device_type, device.status,
                device.ip_address, device.last_seen, device.location,
                device.description, device.firmware_version, device.battery_level,
                device.is_active, str(device.config), str(device.capabilities),
                datetime.now()
            ))
            await db.commit()
    
    async def get_device(self, device_id: str) -> Optional[Device]:
        """Get device by ID"""
        async with aiosqlite.connect(self.db_path) as db:
            cursor = await db.execute('SELECT * FROM devices WHERE id = ?', (device_id,))
            row = await cursor.fetchone()
            
            if row:
                return self._row_to_device(row)
            return None
    
    async def get_all_devices(self) -> List[Device]:
        """Get all devices"""
        async with aiosqlite.connect(self.db_path) as db:
            cursor = await db.execute('SELECT * FROM devices WHERE is_active = 1')
            rows = await cursor.fetchall()
            
            devices = []
            for row in rows:
                device = self._row_to_device(row)
                # Get latest sensor readings for this device
                device.latest_readings = await self.get_latest_sensor_readings(device.id)
                devices.append(device)
            
            return devices
    
    async def update_device_status(self, device_id: str, status: DeviceStatus):
        """Update device status"""
        async with aiosqlite.connect(self.db_path) as db:
            await db.execute('''
                UPDATE devices 
                SET status = ?, last_seen = ?, updated_at = ?
                WHERE id = ?
            ''', (status, datetime.now(), datetime.now(), device_id))
            await db.commit()
    
    # Sensor readings operations
    async def add_sensor_reading(self, reading: SensorReading):
        """Add sensor reading to database"""
        async with aiosqlite.connect(self.db_path) as db:
            await db.execute('''
                INSERT INTO sensor_readings 
                (device_id, sensor_type, value, unit, timestamp)
                VALUES (?, ?, ?, ?, ?)
            ''', (
                reading.device_id, reading.sensor_type, reading.value,
                reading.unit, reading.timestamp
            ))
            await db.commit()
    
    async def get_latest_sensor_readings(self, device_id: str) -> List[SensorReading]:
        """Get latest sensor readings for a device"""
        async with aiosqlite.connect(self.db_path) as db:
            cursor = await db.execute('''
                SELECT * FROM sensor_readings 
                WHERE device_id = ? 
                AND timestamp > datetime('now', '-1 hour')
                ORDER BY sensor_type, timestamp DESC
            ''', (device_id,))
            rows = await cursor.fetchall()
            
            # Get the latest reading for each sensor type
            readings_by_type = {}
            for row in rows:
                sensor_type = row[2]
                if sensor_type not in readings_by_type:
                    readings_by_type[sensor_type] = self._row_to_sensor_reading(row)
            
            return list(readings_by_type.values())
    
    async def get_sensor_history(self, device_id: str, hours: int = 24) -> List[SensorReading]:
        """Get sensor readings history"""
        async with aiosqlite.connect(self.db_path) as db:
            cursor = await db.execute('''
                SELECT * FROM sensor_readings 
                WHERE device_id = ? 
                AND timestamp > datetime('now', '-{} hours')
                ORDER BY timestamp DESC
            '''.format(hours), (device_id,))
            rows = await cursor.fetchall()
            
            return [self._row_to_sensor_reading(row) for row in rows]
    
    # Logging operations
    async def add_log(self, log_entry: LogEntry):
        """Add log entry to database"""
        async with aiosqlite.connect(self.db_path) as db:
            await db.execute('''
                INSERT INTO system_logs 
                (level, message, timestamp, device_id, component, details)
                VALUES (?, ?, ?, ?, ?, ?)
            ''', (
                log_entry.level, log_entry.message, log_entry.timestamp,
                log_entry.device_id, log_entry.component, str(log_entry.details)
            ))
            await db.commit()
    
    async def get_logs(self, limit: int = 100, device_id: Optional[str] = None) -> List[LogEntry]:
        """Get system logs"""
        async with aiosqlite.connect(self.db_path) as db:
            query = 'SELECT * FROM system_logs'
            params = []
            
            if device_id:
                query += ' WHERE device_id = ?'
                params.append(device_id)
            
            query += ' ORDER BY timestamp DESC LIMIT ?'
            params.append(limit)
            
            cursor = await db.execute(query, params)
            rows = await cursor.fetchall()
            
            return [self._row_to_log_entry(row) for row in rows]
    
    # Configuration operations
    async def get_config(self, key: str) -> Optional[str]:
        """Get configuration value"""
        async with aiosqlite.connect(self.db_path) as db:
            cursor = await db.execute('SELECT value FROM system_config WHERE key = ?', (key,))
            row = await cursor.fetchone()
            return row[0] if row else None
    
    async def set_config(self, key: str, value: str):
        """Set configuration value"""
        async with aiosqlite.connect(self.db_path) as db:
            await db.execute('''
                INSERT OR REPLACE INTO system_config (key, value, updated_at)
                VALUES (?, ?, ?)
            ''', (key, value, datetime.now()))
            await db.commit()
    
    async def get_all_config(self) -> Dict[str, str]:
        """Get all configuration values"""
        async with aiosqlite.connect(self.db_path) as db:
            cursor = await db.execute('SELECT key, value FROM system_config')
            rows = await cursor.fetchall()
            return {row[0]: row[1] for row in rows}
    
    # Helper methods
    def _row_to_device(self, row) -> Device:
        """Convert database row to Device object"""
        return Device(
            id=row[0],
            name=row[1],
            device_type=DeviceType(row[2]),
            status=DeviceStatus(row[3]),
            ip_address=row[4],
            last_seen=datetime.fromisoformat(row[5]) if row[5] else None,
            location=row[6],
            description=row[7],
            firmware_version=row[8],
            battery_level=row[9],
            is_active=bool(row[10]),
            config=eval(row[11]) if row[11] else {},
            capabilities=eval(row[12]) if row[12] else []
        )
    
    def _row_to_sensor_reading(self, row) -> SensorReading:
        """Convert database row to SensorReading object"""
        return SensorReading(
            device_id=row[1],
            sensor_type=SensorType(row[2]),
            value=row[3],
            unit=row[4],
            timestamp=datetime.fromisoformat(row[5])
        )
    
    def _row_to_log_entry(self, row) -> LogEntry:
        """Convert database row to LogEntry object"""
        return LogEntry(
            id=row[0],
            level=LogLevel(row[1]),
            message=row[2],
            timestamp=datetime.fromisoformat(row[3]),
            device_id=row[4],
            component=row[5],
            details=eval(row[6]) if row[6] else None
        ) 