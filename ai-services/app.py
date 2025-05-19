from flask import Flask, request, jsonify
from dotenv import load_dotenv
import os
import google.generativeai as genai
from moviepy.editor import VideoFileClip, ImageClip, concatenate_videoclips
import tempfile
import uuid

# Load environment variables
load_dotenv()

# Initialize Flask app
app = Flask(__name__)

# Configure Gemini API
genai.configure(api_key=os.getenv('GEMINI_API_KEY'))
model = genai.GenerativeModel('gemini-pro')

# Helper function for itinerary generation
def generate_itinerary(cities, preferences):
    prompt = f"""
    Generate a detailed travel itinerary for the following cities: {', '.join(cities)}
    User preferences: {preferences}
    
    Include:
    1. Daily schedule
    2. Key attractions
    3. Local food recommendations
    4. Transportation tips
    5. Estimated costs
    
    Format the response as a structured JSON object.
    """
    
    try:
        response = model.generate_content(prompt)
        return response.text
    except Exception as e:
        return {"error": str(e)}

# Helper function for video generation
def generate_video(media_files, duration=30):
    try:
        clips = []
        for file in media_files:
            if file.filename.lower().endswith(('.mp4', '.mov')):
                clip = VideoFileClip(file)
                clips.append(clip)
            elif file.filename.lower().endswith(('.jpg', '.png')):
                clip = ImageClip(file).set_duration(5)
                clips.append(clip)
        
        if not clips:
            raise ValueError("No valid media files provided")
        
        # Concatenate clips
        final_clip = concatenate_videoclips(clips)
        
        # Export to temporary file
        output_path = os.path.join(tempfile.gettempdir(), f"{uuid.uuid4()}.mp4")
        final_clip.write_videofile(output_path, fps=24)
        
        return output_path
    except Exception as e:
        return {"error": str(e)}

# Routes
@app.route('/api/generate-itinerary', methods=['POST'])
def itinerary_endpoint():
    data = request.json
    cities = data.get('cities', [])
    preferences = data.get('preferences', {})
    
    if not cities:
        return jsonify({"error": "No cities provided"}), 400
    
    itinerary = generate_itinerary(cities, preferences)
    return jsonify({"itinerary": itinerary})

@app.route('/api/generate-video', methods=['POST'])
def video_endpoint():
    if 'files' not in request.files:
        return jsonify({"error": "No files provided"}), 400
    
    files = request.files.getlist('files')
    duration = request.form.get('duration', 30, type=int)
    
    output_path = generate_video(files, duration)
    if isinstance(output_path, dict) and 'error' in output_path:
        return jsonify(output_path), 500
    
    # In a production environment, you would upload this to Supabase storage
    # and return the URL instead of the file path
    return jsonify({"video_path": output_path})

if __name__ == '__main__':
    port = int(os.getenv('PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=os.getenv('FLASK_ENV') == 'development') 