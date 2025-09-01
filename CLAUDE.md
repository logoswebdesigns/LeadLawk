# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

LeadLawk is a comprehensive lead generation and management system with a **Flutter frontend** and **Python FastAPI backend**. The system automates discovery and qualification of business leads through Google Maps browser automation, with real-time monitoring and comprehensive lead management workflows.

## Architecture

### Frontend (Flutter - Clean Architecture)
- **State Management**: Riverpod with FutureProvider patterns
- **Navigation**: GoRouter with bottom navigation tabs 
- **API Communication**: Dio HTTP client + WebSocket for real-time updates
- **Code Generation**: json_annotation + build_runner for model serialization

**Structure**:
```
lib/features/leads/
├── domain/          # Business logic (entities, repositories, use cases)
├── data/           # Data layer (models, data sources, implementations) 
└── presentation/   # UI layer (pages, providers, widgets)
```

### Backend (Python FastAPI)
- **Database**: SQLAlchemy 2.0 + SQLite with models: Lead, CallLog, LeadTimelineEntry
- **Browser Automation**: Selenium with containerized Chrome for Google Maps scraping
- **Real-time Updates**: WebSocket connections for live job monitoring
- **Containerization**: Docker Compose with selenium-chrome service

## Development Commands

### Flutter Development
```bash
# From project root
flutter pub get
flutter run
flutter pub run build_runner build --delete-conflicting-outputs  # Regenerate models after schema changes
flutter test
```

### Backend Development  
```bash
# From server/ directory
pip install -r requirements.txt
python main.py                    # Development server on :8000

# Docker (recommended)
docker-compose up -d --build      # Starts FastAPI + Selenium services
docker-compose logs -f leadloq-api  # View server logs
docker-compose down
```

### Quick Scripts
```bash
./start-server.sh                 # One-button server startup
./stop-server.sh                  # Stop all services
```

## Key Systems

### Browser Automation Pipeline
1. **Job Configuration**: Industry, location, qualification thresholds via Flutter UI
2. **Google Maps Scraping**: Selenium automation with progressive scrolling and business extraction
3. **Screenshot Capture**: Business screenshots with retry logic and file verification (fixed timing issues in `browser_automation.py:668-713`)
4. **Real-time Monitoring**: WebSocket updates with progress tracking and cancellation support
5. **Lead Qualification**: Automatic candidate identification (businesses without websites)

### Lead Management Workflow
- **Status Progression**: NEW → CALLED → INTERESTED → CONVERTED → DNC
- **Timeline System**: All interactions tracked in LeadTimelineEntry with types (STATUS_CHANGE, NOTE, FOLLOW_UP, etc.)
- **Navigation**: Advanced lead-to-lead navigation in detail view without returning to list

### Database Schema
```sql
Lead: business_name, phone, website_url, rating, review_count, status, screenshot_path
LeadTimelineEntry: lead_id, entry_type, content, created_at (timeline tracking)
CallLog: lead_id, duration, outcome (call tracking)
```

## Development Workflows

### Adding New Lead Statuses
1. Update `LeadStatus` enum in both Flutter domain entities and Python schemas
2. Regenerate Flutter models: `flutter pub run build_runner build --delete-conflicting-outputs`
3. Update status filtering logic in `LeadsRepository` implementations
4. Test status transitions in lead detail page

### Server Code Changes (CRITICAL)
1. **ALL server changes require container rebuild**: `docker-compose down && docker-compose up -d --build`
2. Core browser logic in `server/browser_automation.py` 
3. Business extraction patterns in `server/business_extractor.py`
4. Screenshot capture uses retry logic with file verification (critical for reliability)
5. **Verification Required**: Always verify changes are in running container with `docker exec leadloq-api grep "your-change" /app/filename.py`

### Adding API Endpoints
1. Define Pydantic schemas in `server/schemas.py`
2. Add endpoint in `server/main.py` with proper error handling
3. Update Flutter data sources in `lib/features/leads/data/datasources/`
4. Add corresponding repository methods and use cases

## Critical Architecture Patterns

### Flutter State Management
- Use `FutureProvider.family` for parameterized data loading
- Implement `leadNavigationProvider` pattern for contextual navigation
- Follow repository pattern: UI → Repository → DataSource → API

### Real-time Updates
- WebSocket connections managed per job ID
- UI subscribes to WebSocket streams via providers
- Automatic reconnection handling for job monitoring

### Screenshot System
- Screenshots saved to `/app/screenshots/` in container, mounted to `./screenshots/` on host
- Web server serves at `/screenshots/` endpoint (not `/static/screenshots/`)
- File verification with retry logic prevents database entries for missing files
- Clean filenames generated from business names (20 char limit)

### Docker Development
- `leadloq-api` service runs FastAPI server
- `selenium-chrome` service provides browser automation (port 4444)
- VNC debugging available at localhost:7900 (password: secret)
- Database persisted via `./db:/app/db` volume mount

## Environment Configuration

### Flutter
- Environment-specific `.env` files (`.env.macos`, `.env.web`)
- API base URL configuration for different platforms
- Mock data generation for testing without backend

### Python/Docker
- `USE_DOCKER=1` environment variable for container detection
- `SELENIUM_HUB_URL` for remote WebDriver connection
- SQLite database path: `/app/db/leadloq.db`

## Code Standards

### SOLID Principles Compliance
- **Strict adherence to SOLID principles required**
- **File length limit: 100 lines maximum per file**
- **No versioned files: Delete old files instead of creating v2/enhanced versions**
- **Clean Architecture: Strict conformance to clean architecture patterns**
- **Known Patterns Only: Use tried and true patterns, avoid obscure or difficult-to-maintain logic**
- **No Task is Complete Until Built and Tested: Never mark tasks complete without successful compilation and testing**
- **Always Verify No Errors Before Completion: Run `flutter analyze` and `flutter test` to ensure no compilation errors exist before claiming work is complete**
- **Never Deliver Code With Errors: Code must compile and pass basic tests - unacceptable to deliver broken code**
- Single Responsibility: Each class/function has one reason to change
- Open/Closed: Extend functionality without modifying existing code
- Liskov Substitution: Derived classes must be substitutable for base classes
- Interface Segregation: Clients shouldn't depend on unused interfaces
- Dependency Inversion: Depend on abstractions, not concretions

When files exceed 100 lines, refactor into smaller, focused modules. Extract related functions into separate utility files or break large classes into smaller, single-purpose classes.

**File Management Rules:**
- Never create versioned files (file_v2.dart, enhanced_file.py, etc.)
- Always refactor existing files in place or properly rename/delete old versions
- Clean up deprecated files immediately to prevent technical debt
- Use git for version history, not file naming conventions

## Testing Standards

### Component Testing Requirements
- **Every new component must have at least 1 test**
- Test files should be placed in the `test/` directory with matching structure
- Widget tests should verify:
  - Component renders without errors
  - Key interactions work as expected
  - State management updates correctly
- Use `flutter test` to run all tests before marking tasks complete

## Testing & Debugging

### Browser Automation Debugging
- Use visible browser mode for debugging: `"browser_mode": "visible"`
- VNC into selenium container: `http://localhost:7900` (password: secret)
- Screenshot capture provides visual debugging of automation steps
- Check logs: `docker-compose logs -f leadloq-api`

### Database Operations
```bash
# Access database directly
sqlite3 server/db/leadloq.db ".tables"
sqlite3 server/db/leadloq.db "SELECT * FROM leads WHERE status = 'NEW' LIMIT 5;"
```

### Common Debugging
- Screenshot failures: Check `browser_automation.py` file verification logic
- WebSocket disconnections: Monitor job status and reconnection handling
- Lead duplication: Business matching uses phone number as primary key
- Build issues: Clean Flutter build with `flutter clean && flutter pub get`