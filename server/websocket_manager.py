#!/usr/bin/env python3
"""
WebSocket connection management for real-time updates
"""

import json
import asyncio
from typing import List
from pathlib import Path
from fastapi import WebSocket, WebSocketDisconnect
from job_management import job_statuses


class JobWebSocketManager:
    """Manage WebSocket connections for job updates"""
    
    def __init__(self):
        self.active_connections: List[WebSocket] = []
        self.job_connections: dict = {}  # job_id -> list of websockets

    async def connect(self, websocket: WebSocket, job_id: str):
        """Connect a WebSocket for a specific job"""
        await websocket.accept()
        self.active_connections.append(websocket)
        
        if job_id not in self.job_connections:
            self.job_connections[job_id] = []
        self.job_connections[job_id].append(websocket)

    def disconnect(self, websocket: WebSocket, job_id: str):
        """Disconnect a WebSocket"""
        if websocket in self.active_connections:
            self.active_connections.remove(websocket)
        
        if job_id in self.job_connections and websocket in self.job_connections[job_id]:
            self.job_connections[job_id].remove(websocket)

    async def send_job_update(self, job_id: str, message: dict):
        """Send update to all connections for a specific job"""
        if job_id in self.job_connections:
            # Wrap message in proper format expected by Flutter client
            formatted_message = {
                "type": "status",
                "data": message
            }
            
            disconnected = []
            for websocket in self.job_connections[job_id]:
                try:
                    await websocket.send_text(json.dumps(formatted_message))
                except:
                    disconnected.append(websocket)
            
            # Remove disconnected websockets
            for ws in disconnected:
                self.disconnect(ws, job_id)
    
    async def send_log_message(self, job_id: str, log_data: dict):
        """Send log message to all connections for a specific job"""
        if job_id in self.job_connections:
            # Format log message for Flutter client
            formatted_message = {
                "type": "log",
                "message": log_data.get("message", ""),
                "timestamp": log_data.get("timestamp", "")
            }
            
            disconnected = []
            for websocket in self.job_connections[job_id]:
                try:
                    await websocket.send_text(json.dumps(formatted_message))
                except:
                    disconnected.append(websocket)
            
            # Remove disconnected websockets
            for ws in disconnected:
                self.disconnect(ws, job_id)

    async def handle_job_websocket(self, websocket: WebSocket, job_id: str):
        """Handle WebSocket connection for job updates"""
        await self.connect(websocket, job_id)
        
        # Send initial status
        if job_id in job_statuses:
            status_message = {
                "type": "status",
                "data": job_statuses[job_id]
            }
            await websocket.send_text(json.dumps(status_message))
        
        # Track last sent log index
        last_log_index = 0
        
        try:
            # Keep connection alive and send periodic updates
            while True:
                # Wait for any message (just to keep connection alive)
                try:
                    await asyncio.wait_for(websocket.receive_text(), timeout=1.0)
                except asyncio.TimeoutError:
                    # Send status update
                    if job_id in job_statuses:
                        status_message = {
                            "type": "status", 
                            "data": job_statuses[job_id]
                        }
                        await websocket.send_text(json.dumps(status_message))
                        
                        # Send any new logs
                        logs = job_statuses[job_id].get('logs', [])
                        if len(logs) > last_log_index:
                            # Send new logs
                            for log in logs[last_log_index:]:
                                log_message = {
                                    "type": "log",
                                    "message": log.get("message", ""),
                                    "timestamp": log.get("timestamp", "")
                                }
                                await websocket.send_text(json.dumps(log_message))
                            last_log_index = len(logs)
                except:
                    break
                    
        except WebSocketDisconnect:
            pass
        finally:
            self.disconnect(websocket, job_id)


class PageSpeedWebSocketManager:
    """Manage WebSocket connections for PageSpeed updates"""
    
    def __init__(self):
        self.active_connections: List[WebSocket] = []
    
    async def connect(self, websocket: WebSocket):
        """Connect a WebSocket for PageSpeed updates"""
        await websocket.accept()
        self.active_connections.append(websocket)
    
    def disconnect(self, websocket: WebSocket):
        """Disconnect a WebSocket"""
        if websocket in self.active_connections:
            self.active_connections.remove(websocket)
    
    async def broadcast_pagespeed_update(self, lead_id: str, update_type: str, data: dict):
        """Broadcast PageSpeed update to all connected clients"""
        message = {
            "type": "pagespeed_update",
            "update_type": update_type,  # "score_received", "lead_deleted", "test_started"
            "lead_id": lead_id,
            "data": data
        }
        
        disconnected = []
        for websocket in self.active_connections:
            try:
                await websocket.send_text(json.dumps(message))
            except:
                disconnected.append(websocket)
        
        # Remove disconnected websockets
        for ws in disconnected:
            self.disconnect(ws)
    
    async def handle_pagespeed_websocket(self, websocket: WebSocket):
        """Handle WebSocket connection for PageSpeed updates"""
        await self.connect(websocket)
        
        try:
            # Send initial connection message
            await websocket.send_text(json.dumps({
                "type": "connected",
                "message": "PageSpeed WebSocket connected"
            }))
            
            # Keep connection alive
            while True:
                try:
                    await asyncio.wait_for(websocket.receive_text(), timeout=30.0)
                except asyncio.TimeoutError:
                    # Send heartbeat
                    await websocket.send_text(json.dumps({
                        "type": "heartbeat",
                        "timestamp": asyncio.get_event_loop().time()
                    }))
                except:
                    break
                    
        except WebSocketDisconnect:
            pass
        finally:
            self.disconnect(websocket)


class LogWebSocketManager:
    """Manage WebSocket connections for log streaming"""
    
    def __init__(self):
        self.active_connections: List[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        """Connect a WebSocket for log streaming"""
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket):
        """Disconnect a WebSocket"""
        if websocket in self.active_connections:
            self.active_connections.remove(websocket)

    async def send_log_update(self, message: dict):
        """Send log update to all connected clients"""
        # Wrap message in proper format expected by Flutter client
        formatted_message = {
            "type": "log",
            "message": message.get("message", str(message))
        }
        
        disconnected = []
        for websocket in self.active_connections:
            try:
                await websocket.send_text(json.dumps(formatted_message))
            except:
                disconnected.append(websocket)
        
        # Remove disconnected websockets
        for ws in disconnected:
            self.disconnect(ws)

    async def handle_log_websocket(self, websocket: WebSocket):
        """Handle WebSocket connection for log streaming"""
        await self.connect(websocket)
        
        try:
            # Send recent log entries
            log_file = Path("server.log")
            if log_file.exists():
                with open(log_file, 'r') as f:
                    lines = f.readlines()
                    # Send last 50 lines
                    recent_lines = lines[-50:] if len(lines) > 50 else lines
                    for line in recent_lines:
                        await websocket.send_text(json.dumps({
                            "type": "log",
                            "message": line.strip()
                        }))
            
            # Keep connection alive
            while True:
                try:
                    await asyncio.wait_for(websocket.receive_text(), timeout=30.0)
                except asyncio.TimeoutError:
                    # Send heartbeat
                    await websocket.send_text(json.dumps({
                        "type": "heartbeat",
                        "timestamp": asyncio.get_event_loop().time()
                    }))
                except:
                    break
                    
        except WebSocketDisconnect:
            pass
        finally:
            self.disconnect(websocket)


# Global instances
job_websocket_manager = JobWebSocketManager()
log_websocket_manager = LogWebSocketManager()
pagespeed_websocket_manager = PageSpeedWebSocketManager()