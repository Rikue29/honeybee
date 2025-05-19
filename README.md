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
