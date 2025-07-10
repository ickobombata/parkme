import { Component, OnInit } from '@angular/core';
import { BreakpointObserver, Breakpoints } from '@angular/cdk/layout';
import { Observable } from 'rxjs';
import { map, shareReplay } from 'rxjs/operators';
import { DeviceService } from './services/device.service';
import { WebSocketService } from './services/websocket.service';

@Component({
  selector: 'app-root',
  templateUrl: './app.component.html',
  styleUrls: ['./app.component.scss']
})
export class AppComponent implements OnInit {
  title = 'Home IoT Control';
  
  isHandset$: Observable<boolean> = this.breakpointObserver.observe(Breakpoints.Handset)
    .pipe(
      map(result => result.matches),
      shareReplay()
    );

  navigationItems = [
    { name: 'Home', icon: 'home', route: '/home' },
    { name: 'Functions', icon: 'build', route: '/functions' },
    { name: 'Logs', icon: 'receipt_long', route: '/logs' },
    { name: 'Settings', icon: 'settings', route: '/settings' }
  ];

  constructor(
    private breakpointObserver: BreakpointObserver,
    private deviceService: DeviceService,
    private webSocketService: WebSocketService
  ) {}

  ngOnInit(): void {
    // Initialize WebSocket connection for real-time updates
    this.webSocketService.connect();
    
    // Load initial device data
    this.deviceService.refreshDevices();
  }
} 