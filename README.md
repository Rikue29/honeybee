# 🐝 Honeybee - Gamified Travel App

Honeybee is a gamified travel application inspired by The Amazing Race, combining location-based quests, AI-powered itinerary planning, and social features to create an engaging travel experience.

## 🏗️ Architecture

### Frontend (`/frontend`)
- **Tech Stack**: Flutter (Dart)
- **Key Features**:
  - Location tracking and quest check-ins
  - Interactive maps (Mapbox + Google Maps)
  - User authentication (Supabase)
  - Real-time quest progress
  - Media upload and sharing
- **Environment**: Uses `flutter_dotenv` for API keys

### Backend (`/backend`)
- **Tech Stack**: Node.js + Express
- **Key Features**:
  - RESTful API endpoints
  - User data management
  - Media storage (Supabase)
  - AI service orchestration
  - Authentication middleware
- **Database**: Supabase (PostgreSQL)
- **Storage**: Supabase Storage Buckets

### AI Services (`/ai-services`)
- **Tech Stack**: Python
- **Key Features**:
  - Itinerary generation (Gemini API)
  - Video processing (MoviePy + ffmpeg)
  - Media transformation
- **Integration**: Triggered via REST endpoints or CLI

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (latest stable)
- Node.js (v18+)
- Python 3.9+
- Supabase account
- Mapbox API key
- Google Maps API key
- Gemini API key

### Environment Setup
1. Clone the repository
2. Copy `.env.sample` to `.env` in each directory:
   - `/frontend/.env`
   - `/backend/.env`
   - `/ai-services/.env`
3. Fill in your API keys and configuration

### Development
1. **Frontend**:
   ```bash
   cd frontend
   flutter pub get
   flutter run
   ```

2. **Backend**:
   ```bash
   cd backend
   npm install
   npm run dev
   ```

3. **AI Services**:
   ```bash
   cd ai-services
   python -m venv venv
   source venv/bin/activate  # or `venv\Scripts\activate` on Windows
   pip install -r requirements.txt
   python app.py
   ```

## 🔄 Service Integration

### Authentication Flow
1. User logs in via Flutter app using Supabase Auth
2. Backend validates JWT tokens
3. Protected routes require valid auth headers

### Location Tracking
1. Flutter app uses background location services
2. Location updates sent to backend
3. Backend validates check-ins against quest locations
4. Points awarded for successful check-ins

### AI Service Integration
1. Backend receives itinerary requests
2. Python scripts triggered via REST endpoints
3. Results cached in Supabase
4. Frontend polls for completion

## 📝 API Documentation

Detailed API documentation is available in:
- `/backend/docs/api.md` - Backend endpoints
- `/ai-services/docs/api.md` - AI service endpoints

## 🔒 Security

- All API keys stored in environment variables
- JWT-based authentication
- Rate limiting on public endpoints
- Secure file upload handling
- Input validation on all endpoints

## 🐳 Docker Support (Optional)

A `docker-compose.yml` file is provided for containerized development:
```bash
docker-compose up
```

## 📄 License

MIT License - see LICENSE file for details

# Honeybee Travel App

A Flutter application that generates personalized travel itineraries for Pekan, Pahang using AI.

## Setup Instructions

1. Install Flutter and set up your development environment following the [official Flutter documentation](https://flutter.dev/docs/get-started/install).

2. Clone this repository:
```bash
git clone https://github.com/yourusername/honeybee.git
cd honeybee
```

3. Get a Mapbox access token:
   - Sign up for a Mapbox account at [mapbox.com](https://www.mapbox.com)
   - Create a new access token with the following scopes:
     - styles:read
     - styles:tiles
     - fonts:read
     - datasets:read

4. Create a `.env` file in the `frontend` directory with your Mapbox access token:
```bash
cd frontend
echo "MAPBOX_ACCESS_TOKEN=your_mapbox_access_token_here" > .env
```

5. Install dependencies:
```bash
flutter pub get
```

6. Replace placeholder images in `frontend/assets/images/` with actual images:
   - `bee_icon.png`: The app's main icon
   - `bee_quest.png`: Quest-related icon
   - `pekan_thumbnail.png`: Thumbnail image for Pekan

7. Run the app:
```bash
flutter run
```

## Features

- Interactive map interface using Mapbox
- Customizable travel preferences:
  - Trip duration
  - Interests (Historical Sites, Nature, Local Culture, etc.)
  - Cuisine preferences
- AI-powered itinerary generation
- Focus on Pekan, Pahang destinations

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.
