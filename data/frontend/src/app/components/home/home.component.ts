import { Component, OnInit, OnDestroy } from '@angular/core';
import { Subject } from 'rxjs';
import { takeUntil } from 'rxjs/operators';
import { DeviceService, Device, SensorReading, SystemStatus } from '../../services/device.service';
import { WebSocketService } from '../../services/websocket.service';

@Component({
  selector: 'app-home',
  templateUrl: './home.component.html',
  styleUrls: ['./home.component.scss']
})
export class HomeComponent implements OnInit, OnDestroy {
  private destroy$ = new Subject<void>();
  
  devices: Device[] = [];
  systemStatus: SystemStatus | null = null;
  sensorData: SensorReading[] = [];
  loading = false;
  lastUpdated: Date = new Date();

  // Stats for dashboard cards
  stats = {
    totalDevices: 0,
    onlineDevices: 0,
    temperature: 0,
    humidity: 0,
    soilMoisture: 0
  };

  constructor(
    private deviceService: DeviceService,
    private webSocketService: WebSocketService
  ) {}

  ngOnInit(): void {
    this.loadDashboardData();
    this.subscribeToRealtimeUpdates();
  }

  ngOnDestroy(): void {
    this.destroy$.next();
    this.destroy$.complete();
  }

  private loadDashboardData(): void {
    this.loading = true;
    
    // Load devices
    this.deviceService.devices$
      .pipe(takeUntil(this.destroy$))
      .subscribe(devices => {
        this.devices = devices;
        this.updateStats();
        this.loading = false;
      });

    // Load system status
    this.deviceService.getSystemStatus()
      .pipe(takeUntil(this.destroy$))
      .subscribe(status => {
        this.systemStatus = status;
        this.lastUpdated = new Date();
      });

    // Load sensor data for all devices
    this.loadSensorData();
  }

  private loadSensorData(): void {
    this.devices.forEach(device => {
      if (device.capabilities.includes('temperature_reading') || 
          device.capabilities.includes('humidity_reading') || 
          device.capabilities.includes('soil_moisture_reading')) {
        
        this.deviceService.getLatestSensorData(device.id)
          .pipe(takeUntil(this.destroy$))
          .subscribe(readings => {
            this.sensorData = [...this.sensorData, ...readings];
            this.updateStats();
          });
      }
    });
  }

  private subscribeToRealtimeUpdates(): void {
    // Subscribe to system status updates
    this.webSocketService.onSystemStatusUpdate()
      .pipe(takeUntil(this.destroy$))
      .subscribe(status => {
        this.systemStatus = status;
        this.lastUpdated = new Date();
      });

    // Subscribe to sensor data updates
    this.webSocketService.onSensorDataUpdate()
      .pipe(takeUntil(this.destroy$))
      .subscribe(data => {
        this.sensorData = [...this.sensorData, ...data.readings];
        this.updateStats();
      });
  }

  private updateStats(): void {
    this.stats.totalDevices = this.devices.length;
    this.stats.onlineDevices = this.devices.filter(d => d.status === 'online').length;

    // Update sensor stats
    const latestTemp = this.getLatestSensorValue('temperature');
    const latestHumidity = this.getLatestSensorValue('humidity');
    const latestSoilMoisture = this.getLatestSensorValue('soil_moisture');

    if (latestTemp !== null) this.stats.temperature = latestTemp;
    if (latestHumidity !== null) this.stats.humidity = latestHumidity;
    if (latestSoilMoisture !== null) this.stats.soilMoisture = latestSoilMoisture;
  }

  private getLatestSensorValue(sensorType: string): number | null {
    const readings = this.sensorData.filter(r => r.sensor_type === sensorType);
    if (readings.length === 0) return null;
    
    // Sort by timestamp and get the latest
    const sorted = readings.sort((a, b) => 
      new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime()
    );
    
    return sorted[0].value;
  }

  onRefresh(): void {
    this.deviceService.refreshDevices();
    this.loadDashboardData();
  }

  getDeviceStatusColor(status: string): string {
    switch (status) {
      case 'online': return '#4caf50';
      case 'offline': return '#f44336';
      case 'error': return '#ff9800';
      default: return '#9e9e9e';
    }
  }

  getDeviceStatusIcon(status: string): string {
    switch (status) {
      case 'online': return 'check_circle';
      case 'offline': return 'offline_bolt';
      case 'error': return 'error';
      default: return 'help';
    }
  }

  getSensorIcon(sensorType: string): string {
    switch (sensorType) {
      case 'temperature': return 'thermostat';
      case 'humidity': return 'water_drop';
      case 'soil_moisture': return 'grass';
      case 'light_level': return 'wb_sunny';
      default: return 'sensors';
    }
  }

  formatSensorValue(value: number, unit: string): string {
    return `${value.toFixed(1)} ${unit}`;
  }
} 