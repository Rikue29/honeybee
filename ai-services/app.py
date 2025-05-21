from flask import Flask, request, jsonify
from flask_cors import CORS
import os
import tempfile
from moviepy.editor import VideoFileClip, ImageClip, concatenate_videoclips, TextClip, CompositeVideoClip, AudioFileClip, ColorClip
import uuid
from datetime import datetime
from dotenv import load_dotenv
import moviepy.video.fx.all as vfx
import cv2
import numpy as np

# Configure MoviePy to use ImageMagick
from moviepy.config import change_settings
change_settings({"IMAGEMAGICK_BINARY": "magick"})  # Using the command directly since it's in PATH

# Load environment variables
load_dotenv()

# Initialize Flask app
app = Flask(__name__)

# Helper function for video generation
def resize_and_pad(clip, target_size=(720, 1280)):
    w, h = target_size

    def make_blur_frame(get_frame, t):
        frame = get_frame(t)
        # Convert to OpenCV format
        frame_cv = cv2.cvtColor(frame, cv2.COLOR_RGB2BGR)
        # Resize to fill background
        bg = cv2.resize(frame_cv, (w, h))
        # Apply Gaussian blur
        bg = cv2.GaussianBlur(bg, (99, 99), 30)
        # Resize original to fit inside target
        ih, iw = frame.shape[:2]
        scale = min(w / iw, h / ih)
        nw, nh = int(iw * scale), int(ih * scale)
        fg = cv2.resize(frame_cv, (nw, nh))
        # Center foreground on background
        x1 = (w - nw) // 2
        y1 = (h - nh) // 2
        bg[y1:y1+nh, x1:x1+nw] = fg
        # Convert back to MoviePy format
        return cv2.cvtColor(bg, cv2.COLOR_BGR2RGB)

    # For images
    if hasattr(clip, 'img'):
        def make_blur_image():
            frame = clip.img
            frame_cv = cv2.cvtColor(frame, cv2.COLOR_RGB2BGR)
            bg = cv2.resize(frame_cv, (w, h))
            bg = cv2.GaussianBlur(bg, (99, 99), 30)
            ih, iw = frame.shape[:2]
            scale = min(w / iw, h / ih)
            nw, nh = int(iw * scale), int(ih * scale)
            fg = cv2.resize(frame_cv, (nw, nh))
            x1 = (w - nw) // 2
            y1 = (h - nh) // 2
            bg[y1:y1+nh, x1:x1+nw] = fg
            return cv2.cvtColor(bg, cv2.COLOR_BGR2RGB)
        return ImageClip(make_blur_image()).set_duration(clip.duration)
    else:
        # For videos
        return clip.fl(lambda gf, t: make_blur_frame(gf, t)).set_duration(clip.duration)

def generate_video(media_files, duration=30, music_path='sound/default_music.mp3', title_text="My Journey"):
    try:
        target_size = (720, 1280)  # Portrait for mobile
        clips = []
        for file in media_files:
            filename = file.filename.lower()
            with tempfile.NamedTemporaryFile(delete=False, suffix=os.path.splitext(filename)[-1]) as temp:
                file.save(temp)
                temp_path = temp.name

            if filename.endswith(('.mp4', '.mov')):
                clip = VideoFileClip(temp_path)
            elif filename.endswith(('.jpg', '.png')):
                try:
                    image_duration = float(duration)
                    image_duration = min(max(image_duration, 1), 5)
                except (ValueError, TypeError):
                    image_duration = 5
                clip = ImageClip(temp_path).set_duration(image_duration)
            else:
                continue
            # Resize and pad
            clip = resize_and_pad(clip, target_size)
            clips.append(clip)

        if not clips:
            raise ValueError("No valid media files provided")

        if title_text:
            title_clip = TextClip(title_text, fontsize=70, color='white', bg_color='black', size=target_size)
            title_clip = title_clip.set_duration(3)
            clips = [title_clip] + clips

        final_clips = []
        for i, clip in enumerate(clips):
            if i > 0:
                clip = clip.crossfadein(1.0)
            final_clips.append(clip)
        final = concatenate_videoclips(final_clips, method="compose")

        if music_path and os.path.exists(music_path):
            audio = AudioFileClip(music_path)
            if audio.duration > final.duration:
                audio = audio.subclip(0, final.duration)
            elif audio.duration < final.duration:
                audio = audio.loop(duration=final.duration)
            final = final.set_audio(audio)

        downloads_dir = os.path.join(os.path.expanduser('~'), 'Downloads')
        if not os.path.exists(downloads_dir):
            os.makedirs(downloads_dir)
        output_path = os.path.join(downloads_dir, f"{uuid.uuid4()}.mp4")

        # Faster encoding, lower bitrate, smaller size
        final.write_videofile(
            output_path,
            fps=24,
            codec='libx264',
            audio_codec='aac',
            bitrate='1000k',
            audio_bitrate='96k',
            preset='ultrafast',
            threads=4,
            ffmpeg_params=[
                '-pix_fmt', 'yuv420p',
                '-movflags', '+faststart'
            ]
        )
        return output_path
    except Exception as e:
        print(f"Error in generate_video: {str(e)}")
        import traceback
        print(f"Traceback: {traceback.format_exc()}")
        return {"error": str(e)}

# Routes
@app.route('/api/generate-video', methods=['POST'])
def video_endpoint():
    try:
        print("Received request")
        print("request.files:", request.files)
        print("request.form:", request.form)
        
        if 'files' not in request.files:
            print("No files in request.files")
            return jsonify({"error": "No files provided"}), 400

        files = request.files.getlist('files')
        print(f"Number of files received: {len(files)}")
        
        # Get and validate duration
        try:
            duration = request.form.get('duration', default=30, type=int)
            print(f"Duration from request: {duration}")
        except ValueError:
            print("Invalid duration value, using default")
            duration = 30
            
        music_path = request.form.get('music_path', default='sound/default_music.mp3')
        title_text = request.form.get('title_text', default="My Journey")

        print(f"Calling generate_video with duration={duration}")
        output_path = generate_video(files, duration, music_path, title_text)
        
        if isinstance(output_path, dict) and 'error' in output_path:
            print(f"Error in generate_video: {output_path['error']}")
            return jsonify(output_path), 500

        return jsonify({"video_path": output_path})
    except Exception as e:
        print(f"Error in video_endpoint: {str(e)}")
        import traceback
        print(f"Traceback: {traceback.format_exc()}")
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    port = int(os.getenv('PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=os.getenv('FLASK_ENV') == 'development') 