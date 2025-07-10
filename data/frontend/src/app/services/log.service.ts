import { Injectable } from '@angular/core';
import { HttpClient, HttpErrorResponse } from '@angular/common/http';
import { Observable, BehaviorSubject, throwError } from 'rxjs';
import { catchError, tap } from 'rxjs/operators';
import { environment } from '../../environments/environment';

export interface LogEntry {
  id?: number;
  level: string;
  message: string;
  timestamp: string;
  device_id?: string;
  component?: string;
  details?: any;
}

@Injectable({
  providedIn: 'root'
})
export class LogService {
  private apiUrl = environment.apiUrl;
  private logsSubject = new BehaviorSubject<LogEntry[]>([]);
  private loadingSubject = new BehaviorSubject<boolean>(false);

  public logs$ = this.logsSubject.asObservable();
  public loading$ = this.loadingSubject.asObservable();

  constructor(private http: HttpClient) {}

  getLogs(limit: number = 100, deviceId?: string): Observable<LogEntry[]> {
    this.loadingSubject.next(true);
    
    let url = `${this.apiUrl}/logs?limit=${limit}`;
    if (deviceId) {
      url += `&device_id=${deviceId}`;
    }

    return this.http.get<LogEntry[]>(url)
      .pipe(
        tap(logs => {
          this.logsSubject.next(logs);
          this.loadingSubject.next(false);
        }),
        catchError(error => {
          this.loadingSubject.next(false);
          return this.handleError(error);
        })
      );
  }

  refreshLogs(limit: number = 100, deviceId?: string): void {
    this.getLogs(limit, deviceId).subscribe({
      next: (logs) => {
        // Logs are already updated in the tap operator
      },
      error: (error) => {
        console.error('Error refreshing logs:', error);
      }
    });
  }

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

  // Utility methods
  getLogsByLevel(level: string): LogEntry[] {
    return this.logsSubject.value.filter(log => log.level === level);
  }

  getLogsByDevice(deviceId: string): LogEntry[] {
    return this.logsSubject.value.filter(log => log.device_id === deviceId);
  }

  getLogsByComponent(component: string): LogEntry[] {
    return this.logsSubject.value.filter(log => log.component === component);
  }

  // Helper method to get log level color
  getLogLevelColor(level: string): string {
    switch (level.toLowerCase()) {
      case 'error':
      case 'critical':
        return '#f44336';
      case 'warning':
        return '#ff9800';
      case 'info':
        return '#2196f3';
      case 'debug':
        return '#9e9e9e';
      default:
        return '#000000';
    }
  }

  // Helper method to get log level icon
  getLogLevelIcon(level: string): string {
    switch (level.toLowerCase()) {
      case 'error':
      case 'critical':
        return 'error';
      case 'warning':
        return 'warning';
      case 'info':
        return 'info';
      case 'debug':
        return 'bug_report';
      default:
        return 'help';
    }
  }
} 