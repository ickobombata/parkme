import { Injectable } from '@angular/core';
import { Observable, Subject, BehaviorSubject } from 'rxjs';
import { webSocket, WebSocketSubject } from 'rxjs/webSocket';
import { environment } from '../../environments/environment';
import { SystemStatus } from './device.service';

@Injectable({
  providedIn: 'root'
})
export class WebSocketService {
  private socket$: WebSocketSubject<any> | null = null;
  private messagesSubject = new Subject<any>();
  private connectionStatusSubject = new BehaviorSubject<boolean>(false);
  private reconnectInterval = 5000;
  private reconnectAttempts = 0;
  private maxReconnectAttempts = 10;

  public messages$ = this.messagesSubject.asObservable();
  public connectionStatus$ = this.connectionStatusSubject.asObservable();

  constructor() {}

  connect(): void {
    if (this.socket$ && !this.socket$.closed) {
      return;
    }

    const wsUrl = environment.wsUrl || 'ws://localhost:8000/ws';
    
    this.socket$ = webSocket({
      url: wsUrl,
      openObserver: {
        next: () => {
          console.log('WebSocket connected');
          this.connectionStatusSubject.next(true);
          this.reconnectAttempts = 0;
        }
      },
      closeObserver: {
        next: () => {
          console.log('WebSocket disconnected');
          this.connectionStatusSubject.next(false);
          this.reconnect();
        }
      }
    });

    this.socket$.subscribe({
      next: (message) => {
        this.messagesSubject.next(message);
        this.handleMessage(message);
      },
      error: (error) => {
        console.error('WebSocket error:', error);
        this.connectionStatusSubject.next(false);
        this.reconnect();
      }
    });
  }

  private handleMessage(message: any): void {
    // Handle different types of messages
    if (message.status && message.devices) {
      // System status update
      this.handleSystemStatusUpdate(message as SystemStatus);
    } else if (message.type === 'sensor_data') {
      // Sensor data update
      this.handleSensorDataUpdate(message);
    } else if (message.type === 'device_status') {
      // Device status update
      this.handleDeviceStatusUpdate(message);
    }
  }

  private handleSystemStatusUpdate(status: SystemStatus): void {
    // Emit system status update
    this.messagesSubject.next({
      type: 'system_status',
      data: status
    });
  }

  private handleSensorDataUpdate(message: any): void {
    // Emit sensor data update
    this.messagesSubject.next({
      type: 'sensor_data',
      data: message.data
    });
  }

  private handleDeviceStatusUpdate(message: any): void {
    // Emit device status update
    this.messagesSubject.next({
      type: 'device_status',
      data: message.data
    });
  }

  private reconnect(): void {
    if (this.reconnectAttempts < this.maxReconnectAttempts) {
      this.reconnectAttempts++;
      console.log(`Attempting to reconnect WebSocket (${this.reconnectAttempts}/${this.maxReconnectAttempts})`);
      
      setTimeout(() => {
        this.connect();
      }, this.reconnectInterval);
    } else {
      console.error('Max reconnection attempts reached');
    }
  }

  send(message: any): void {
    if (this.socket$ && !this.socket$.closed) {
      this.socket$.next(message);
    } else {
      console.warn('WebSocket is not connected');
    }
  }

  disconnect(): void {
    if (this.socket$) {
      this.socket$.complete();
      this.socket$ = null;
      this.connectionStatusSubject.next(false);
    }
  }

  // Utility methods
  isConnected(): boolean {
    return this.connectionStatusSubject.value;
  }

  // Subscribe to specific message types
  onSystemStatusUpdate(): Observable<SystemStatus> {
    return new Observable(observer => {
      this.messages$.subscribe(message => {
        if (message.type === 'system_status') {
          observer.next(message.data);
        }
      });
    });
  }

  onSensorDataUpdate(): Observable<any> {
    return new Observable(observer => {
      this.messages$.subscribe(message => {
        if (message.type === 'sensor_data') {
          observer.next(message.data);
        }
      });
    });
  }

  onDeviceStatusUpdate(): Observable<any> {
    return new Observable(observer => {
      this.messages$.subscribe(message => {
        if (message.type === 'device_status') {
          observer.next(message.data);
        }
      });
    });
  }
} 