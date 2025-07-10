import { Injectable } from '@angular/core';
import { HttpClient, HttpErrorResponse } from '@angular/common/http';
import { Observable, BehaviorSubject, throwError } from 'rxjs';
import { catchError, tap } from 'rxjs/operators';
import { environment } from '../../environments/environment';

export interface Device {
  id: string;
  name: string;
  device_type: string;
  status: string;
  ip_address?: string;
  last_seen?: string;
  location?: string;
  description?: string;
  firmware_version?: string;
  battery_level?: number;
  is_active: boolean;
  config: any;
  latest_readings: SensorReading[];
  capabilities: string[];
}

export interface SensorReading {
  sensor_type: string;
  value: number;
  unit: string;
  timestamp: string;
  device_id: string;
}

export interface SystemStatus {
  status: string;
  devices: Device[];
  last_updated: string;
}

export interface WaterCommand {
  duration: number;
  device_id: string;
}

export interface ApiResponse {
  success: boolean;
  message: string;
  data?: any;
}

@Injectable({
  providedIn: 'root'
})
export class DeviceService {
  private apiUrl = environment.apiUrl;
  private devicesSubject = new BehaviorSubject<Device[]>([]);
  private systemStatusSubject = new BehaviorSubject<SystemStatus | null>(null);
  private loadingSubject = new BehaviorSubject<boolean>(false);

  public devices$ = this.devicesSubject.asObservable();
  public systemStatus$ = this.systemStatusSubject.asObservable();
  public loading$ = this.loadingSubject.asObservable();

  constructor(private http: HttpClient) {}

  // Device operations
  refreshDevices(): void {
    this.loadingSubject.next(true);
    this.getDevices().subscribe({
      next: (devices) => {
        this.devicesSubject.next(devices);
        this.loadingSubject.next(false);
      },
      error: (error) => {
        console.error('Error loading devices:', error);
        this.loadingSubject.next(false);
      }
    });
  }

  getDevices(): Observable<Device[]> {
    return this.http.get<Device[]>(`${this.apiUrl}/devices`)
      .pipe(
        catchError(this.handleError)
      );
  }

  getDevice(deviceId: string): Observable<Device> {
    return this.http.get<Device>(`${this.apiUrl}/devices/${deviceId}`)
      .pipe(
        catchError(this.handleError)
      );
  }

  getSystemStatus(): Observable<SystemStatus> {
    return this.http.get<SystemStatus>(`${this.apiUrl}/status`)
      .pipe(
        tap(status => this.systemStatusSubject.next(status)),
        catchError(this.handleError)
      );
  }

  // Water control
  startWatering(command: WaterCommand): Observable<ApiResponse> {
    return this.http.post<ApiResponse>(`${this.apiUrl}/water/start`, command)
      .pipe(
        tap(() => this.refreshDevices()),
        catchError(this.handleError)
      );
  }

  stopWatering(deviceId: string = 'arduino_pump'): Observable<ApiResponse> {
    return this.http.post<ApiResponse>(`${this.apiUrl}/water/stop`, { device_id: deviceId })
      .pipe(
        tap(() => this.refreshDevices()),
        catchError(this.handleError)
      );
  }

  // Sensor data
  getLatestSensorData(deviceId: string): Observable<SensorReading[]> {
    return this.http.get<SensorReading[]>(`${this.apiUrl}/sensors/${deviceId}/latest`)
      .pipe(
        catchError(this.handleError)
      );
  }

  getSensorHistory(deviceId: string, hours: number = 24): Observable<SensorReading[]> {
    return this.http.get<SensorReading[]>(`${this.apiUrl}/sensors/${deviceId}/history?hours=${hours}`)
      .pipe(
        catchError(this.handleError)
      );
  }

  // Configuration
  getConfig(): Observable<any> {
    return this.http.get<any>(`${this.apiUrl}/config`)
      .pipe(
        catchError(this.handleError)
      );
  }

  updateConfig(config: any): Observable<ApiResponse> {
    return this.http.post<ApiResponse>(`${this.apiUrl}/config`, config)
      .pipe(
        catchError(this.handleError)
      );
  }

  // Utility methods
  private handleError(error: HttpErrorResponse) {
    let errorMessage = 'An error occurred';
    
    if (error.error instanceof ErrorEvent) {
      // Client-side error
      errorMessage = `Error: ${error.error.message}`;
    } else {
      // Server-side error
      errorMessage = `Error Code: ${error.status}\nMessage: ${error.message}`;
    }
    
    console.error(errorMessage);
    return throwError(() => new Error(errorMessage));
  }

  // Helper method to get device by ID from current state
  getDeviceById(deviceId: string): Device | undefined {
    return this.devicesSubject.value.find(device => device.id === deviceId);
  }

  // Helper method to check if device is online
  isDeviceOnline(deviceId: string): boolean {
    const device = this.getDeviceById(deviceId);
    return device ? device.status === 'online' : false;
  }
} 