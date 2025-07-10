import { Component, OnInit } from '@angular/core';
import { MatSnackBar } from '@angular/material/snack-bar';
import { DeviceService, WaterCommand, Device } from '../../services/device.service';

@Component({
  selector: 'app-functions',
  templateUrl: './functions.component.html',
  styleUrls: ['./functions.component.scss']
})
export class FunctionsComponent implements OnInit {
  devices: Device[] = [];
  loading = false;
  waterDuration = 5;
  selectedDevice = 'dummy_controller';

  constructor(
    public deviceService: DeviceService,
    private snackBar: MatSnackBar
  ) {}

  ngOnInit(): void {
    // Load devices from backend
    this.deviceService.refreshDevices();
    this.loadDevices();
  }

  private loadDevices(): void {
    this.deviceService.devices$.subscribe(devices => {
      this.devices = devices;
    });
  }

  onStartWatering(): void {
    this.loading = true;
    
    const command: WaterCommand = {
      duration: this.waterDuration,
      device_id: this.selectedDevice
    };

    this.deviceService.startWatering(command).subscribe({
      next: (response) => {
        this.loading = false;
        this.snackBar.open(response.message, 'Close', {
          duration: 3000,
          panelClass: ['success-snackbar']
        });
      },
      error: (error) => {
        this.loading = false;
        this.snackBar.open('Failed to start watering: ' + error.message, 'Close', {
          duration: 5000,
          panelClass: ['error-snackbar']
        });
      }
    });
  }

  onStopWatering(): void {
    this.loading = true;
    
    this.deviceService.stopWatering(this.selectedDevice).subscribe({
      next: (response) => {
        this.loading = false;
        this.snackBar.open(response.message, 'Close', {
          duration: 3000,
          panelClass: ['success-snackbar']
        });
      },
      error: (error) => {
        this.loading = false;
        this.snackBar.open('Failed to stop watering: ' + error.message, 'Close', {
          duration: 5000,
          panelClass: ['error-snackbar']
        });
      }
    });
  }

  isPumpDevice(device: Device): boolean {
    return device.device_type === 'pump';
  }

  isDeviceOnline(deviceId: string): boolean {
    return this.deviceService.isDeviceOnline(deviceId);
  }

  getDeviceStatusColor(status: string): string {
    switch (status) {
      case 'online': return '#4caf50';
      case 'offline': return '#f44336';
      case 'error': return '#ff9800';
      default: return '#9e9e9e';
    }
  }
} 