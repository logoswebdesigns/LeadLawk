# LeadLawk

A local lead generation and management system with Flutter UI controls for web scraping. Built with Clean Architecture, this app allows you to discover and manage business leads with customizable qualification thresholds.

## Features

- **UI-Controlled Scraping**: Configure and run scrapes directly from the Flutter app
- **Smart Qualification**: Set custom thresholds for rating, reviews, and recency
- **Lead Management**: Track lead status (New, Called, Interested, Converted, DNC)
- **Platform Detection**: Identifies website builders (GoDaddy, Google Business Sites)
- **Local Storage**: Everything runs locally with SQLite
- **Clean Architecture**: Modular, testable Flutter code with Riverpod state management

## Tech Stack

- **Frontend**: Flutter (Clean Architecture + Riverpod + Dio + GoRouter)
- **Backend**: FastAPI (Python 3.12)
- **Scraping**: Scrapy (polite, HTML-only)
- **Database**: SQLite via SQLAlchemy
- **Platform**: macOS (Apple Silicon compatible)

## Project Structure

```
LeadLawk/
├── lib/                      # Flutter app (Clean Architecture)
│   ├── core/                # Core utilities and error handling
│   ├── features/leads/      # Lead management feature
│   │   ├── domain/          # Business logic and entities
│   │   ├── data/            # Data sources and repositories
│   │   └── presentation/    # UI pages and state management
│   └── main.dart            # App entry point
├── server/                   # Python backend
│   ├── main.py              # FastAPI server
│   ├── models.py            # SQLAlchemy models
│   ├── scraper/             # Scrapy spider
│   └── db/                  # SQLite database location
└── test/                     # Tests
```

## Installation

### Prerequisites

- Flutter SDK (3.0+)
- Python 3.12
- macOS (Apple Silicon or Intel)

### Setup

1. **Clone the repository**
```bash
git clone https://github.com/yourusername/LeadLawk.git
cd LeadLawk
```

2. **Install Flutter dependencies**
```bash
flutter pub get
```

3. **Install Python dependencies**
```bash
cd server
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cd ..

```

## Running the Application

### Start the Backend Server

```bash
cd server
source venv/bin/activate
python main.py
```

The API will be available at `http://localhost:8000`

### Run the Flutter App

In a new terminal:

```bash
flutter run
```

Select your target device (iOS Simulator, Android Emulator, or Chrome for web).

## Usage Guide

### Control the Scraper from the UI

1. **Open Run Scrape Screen**
   - Tap the play button in the app bar

2. **Configure Your Search**
   - **Industry**: Choose from preset chips (Painter, Landscaper, Roofer, Plumber, Electrician) or select "Custom..." for any industry
   - **Location**: Enter a location (e.g., "Austin, TX")
   - **Result Limit**: Set how many results to fetch (1-200)

3. **Set Qualification Thresholds** (Optional)
   - Expand "Advanced Settings"
   - **Min Rating**: Minimum star rating (0-5)
   - **Min Reviews**: Minimum review count
   - **Recent Days**: How recent reviews must be

4. **Run the Scrape**
   - Tap "Run Scrape"
   - Watch the progress bar
   - When complete, you'll be redirected to the Candidates list

### Managing Leads

- **View Leads**: Browse all leads or filter by status/candidates
- **Search**: Use the search bar to find specific businesses
- **Update Status**: Click on a lead and use quick action buttons
- **Add Notes**: Edit notes directly in the lead detail view
- **Call Tracking**: Status automatically tracks your outreach

### Lead Statuses

- 🔘 **New**: Uncontacted leads
- 🟠 **Called**: Attempted contact
- 🔵 **Interested**: Showed interest
- 🟢 **Converted**: Became a customer
- ⚫ **DNC**: Do not contact

## API Endpoints

### Scraping

- `POST /jobs/scrape` - Start a new scrape job
  ```json
  {
    "industry": "painter",
    "location": "Austin, TX",
    "limit": 50,
    "min_rating": 4.0,
    "min_reviews": 3,
    "recent_days": 365
  }
  ```

- `GET /jobs/{job_id}` - Check job status

### Lead Management

- `GET /leads` - List leads (supports filtering)
- `GET /leads/{id}` - Get lead details
- `PUT /leads/{id}` - Update lead status/notes

## Testing

### Flutter Tests

```bash
flutter test
```

### Python Tests

```bash
cd server
pytest test_server.py
```

## Development

### Code Generation (Flutter)

After modifying models:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### Database Reset

To reset the database:

```bash
rm server/db/leadlawk.db
```

The database will be recreated on next server start.

## Configuration

### Scraper Settings

Default thresholds can be modified in the UI's Advanced Settings:
- Min Rating: 4.0 stars
- Min Reviews: 3 reviews  
- Recent Days: 365 days

### API Configuration

Server settings in `server/main.py`:
- Host: `0.0.0.0`
- Port: `8000`

## Troubleshooting

### Android Studio Not Recognizing Flutter Project

1. Close Android Studio
2. Open Android Studio
3. Select "Open" and choose the LeadLawk folder
4. Let it index the project
5. Run configurations should appear

### Server Connection Issues

Ensure the server is running and check:
- Firewall settings
- Port 8000 availability
- CORS configuration in `server/main.py`

### Database Lock Errors

SQLite can lock during concurrent access. Restart the server if this occurs.

## Future Enhancements

- [ ] Real Google Maps scraping (currently using mock data)
- [ ] Export leads to CSV/Excel
- [ ] Email integration
- [ ] Call logging with duration tracking
- [ ] Advanced analytics dashboard
- [ ] Multi-user support

## License

MIT License - See LICENSE file for details

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Open a Pull Request