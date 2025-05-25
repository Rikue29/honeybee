from fastapi import FastAPI, UploadFile, File, Form, Body
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
import os
import tempfile
from moviepy.editor import VideoFileClip, ImageClip, concatenate_videoclips, TextClip, CompositeVideoClip, AudioFileClip, ColorClip
import uuid
from datetime import datetime
from dotenv import load_dotenv
import moviepy.video.fx.all as vfx
import cv2
import numpy as np
from moviepy.config import change_settings
from supabase import create_client, Client
import requests

# Configure ImageMagick path for Windows
if os.name == 'nt':  # Windows
    IMAGEMAGICK_BINARY = r"C:\Program Files\ImageMagick-7.1.1-Q16-HDRI\magick.exe"
    if os.path.exists(IMAGEMAGICK_BINARY):
        change_settings({"IMAGEMAGICK_BINARY": IMAGEMAGICK_BINARY})

# Load environment variables
load_dotenv()

# Supabase config from environment variables
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SERVICE_KEY = os.getenv("SUPABASE_SERVICE_KEY")
SUPABASE_BUCKET = os.getenv("SUPABASE_BUCKET")

supabase: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)

# Initialize FastAPI app
app = FastAPI()

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

def resize_and_pad(clip, portrait_size=(720, 1280), landscape_size=(1280, 720)):
    # Determine original orientation
    if hasattr(clip, 'img'):
        ih, iw = clip.img.shape[:2]
    else:
        ih, iw = clip.size[1], clip.size[0]

    # Choose target size based on orientation
    if iw > ih:
        target_size = landscape_size
    else:
        target_size = portrait_size

    w, h = target_size

    def make_blur_frame(get_frame, t):
        frame = get_frame(t)
        frame_cv = cv2.cvtColor(frame, cv2.COLOR_RGB2BGR)
        bg = cv2.resize(frame_cv, (w, h))
        bg = cv2.GaussianBlur(bg, (99, 99), 30)
        scale = min(w / iw, h / ih)
        nw, nh = int(iw * scale), int(ih * scale)
        fg = cv2.resize(frame_cv, (nw, nh))
        x1 = (w - nw) // 2
        y1 = (h - nh) // 2
        bg[y1:y1+nh, x1:x1+nw] = fg
        return cv2.cvtColor(bg, cv2.COLOR_BGR2RGB)

    if hasattr(clip, 'img'):
        def make_blur_image():
            frame = clip.img
            frame_cv = cv2.cvtColor(frame, cv2.COLOR_RGB2BGR)
            bg = cv2.resize(frame_cv, (w, h))
            bg = cv2.GaussianBlur(bg, (99, 99), 30)
            scale = min(w / iw, h / ih)
            nw, nh = int(iw * scale), int(ih * scale)
            fg = cv2.resize(frame_cv, (nw, nh))
            x1 = (w - nw) // 2
            y1 = (h - nh) // 2
            bg[y1:y1+nh, x1:x1+nw] = fg
            return cv2.cvtColor(bg, cv2.COLOR_BGR2RGB)
        return ImageClip(make_blur_image()).set_duration(clip.duration)
    else:
        return clip.fl(lambda gf, t: make_blur_frame(gf, t)).set_duration(clip.duration)

def create_title_overlay(clip, title_text, target_size):
    try:
        # Create text clip with transparent background
        txt_clip = TextClip(
            title_text,
            fontsize=70,
            color='white',
            stroke_color='black',
            stroke_width=2,
            size=(target_size[0] * 0.9, None),  # 90% of video width
            method='caption'
        )
        # Position text at the top with padding
        txt_clip = txt_clip.set_position(('center', 50))
        # Set duration to match the clip
        txt_clip = txt_clip.set_duration(clip.duration)
        # Composite the text over the video
        return CompositeVideoClip([clip, txt_clip])
    except Exception as e:
        print(f"Warning: Could not create title overlay: {str(e)}")
        return clip

def create_watermark(target_size):
    try:
        # Path to the logo image (relative to ai-services/app.py)
        logo_path = os.path.join(os.path.dirname(__file__), 'HoneybeeLogo.png')
        logo_height = 120  # px
        logo_clip = None
        watermark_duration = 0.5  # seconds (shortened)
        if os.path.exists(logo_path):
            logo_clip = ImageClip(logo_path).resize(height=logo_height)
            logo_clip = logo_clip.set_position(('center', 'center')).set_duration(watermark_duration)
        # Create watermark text
        watermark_text = TextClip(
            "Created by Honeybee",
            fontsize=48,
            color='white',
            stroke_color='black',
            stroke_width=2,
            method='caption',
            size=(target_size[0] * 0.9, None)
        ).set_duration(watermark_duration)
        # Position text below the logo
        if logo_clip:
            # Stack logo and text vertically, centered
            # Calculate y positions
            total_height = logo_clip.h + 20 + watermark_text.h
            logo_y = (target_size[1] - total_height) // 2
            text_y = logo_y + logo_clip.h + 20
            logo_clip = logo_clip.set_position(('center', logo_y))
            watermark_text = watermark_text.set_position(('center', text_y))
            clips = [logo_clip, watermark_text]
        else:
            # Only text, centered
            watermark_text = watermark_text.set_position(('center', 'center'))
            clips = [watermark_text]
        # Black background
        bg = ColorClip(target_size, color=(0, 0, 0)).set_duration(watermark_duration)
        watermark = CompositeVideoClip([bg] + clips, size=target_size).set_duration(watermark_duration)
        return watermark
    except Exception as e:
        print(f"Warning: Could not create watermark: {str(e)}")
        return None

def upload_to_supabase(local_file_path, supabase_path):
    with open(local_file_path, "rb") as f:
        res = supabase.storage.from_(SUPABASE_BUCKET).upload(supabase_path, f)
    # Get the public URL
    public_url = supabase.storage.from_(SUPABASE_BUCKET).get_public_url(supabase_path)
    return public_url

def generate_video(media_file_paths, duration=30, music_path='sound/default_music.mp3', title_text="My Journey"):
    try:
        clips = []
        temp_files_to_clean = []

        for file_path in media_file_paths:
            filename = os.path.basename(file_path).lower()
            temp_path = file_path
            temp_files_to_clean.append(temp_path)

            if filename.endswith(('.mp4', '.mov')):
                clip = VideoFileClip(temp_path)
            elif filename.endswith(('.jpg', '.png')):
                try:
                    image_duration = float(duration)
                    # Limit image duration between 2 and 3 seconds
                    image_duration = min(max(image_duration, 2), 3)
                except (ValueError, TypeError):
                    image_duration = 3
                clip = ImageClip(temp_path).set_duration(image_duration)
            else:
                continue

            clip = resize_and_pad(clip)
            clips.append(clip)

        if not clips:
            raise ValueError("No valid media files provided")

        # Add title overlay to the first clip
        if title_text and clips:
            clips[0] = create_title_overlay(clips[0], title_text, clips[0].size)

        final_clips = []
        for i, clip in enumerate(clips):
            if i > 0:
                clip = clip.crossfadein(1.0)
            final_clips.append(clip)

        # Add watermark at the end
        watermark = create_watermark(clips[0].size)
        if watermark:
            final_clips.append(watermark)

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

        # iOS-compatible video settings
        final.write_videofile(
            output_path,
            fps=30,  # Standard iOS frame rate
            codec='libx264',
            audio_codec='aac',
            bitrate='4000k',  # Higher bitrate for better quality
            audio_bitrate='192k',  # Higher audio quality
            preset='ultrafast',  # Better compression
            threads=4,
            ffmpeg_params=[
                '-pix_fmt', 'yuv420p',  # Required for iOS compatibility
                '-movflags', '+faststart',  # Enables streaming
                '-profile:v', 'high',  # High profile for better quality
                '-level', '4.0',  # Compatibility level
                '-crf', '23'  # Constant Rate Factor for quality
            ]
        )

        # Upload to Supabase Storage
        supabase_path = f"videos/{os.path.basename(output_path)}"
        public_url = upload_to_supabase(output_path, supabase_path)
        
        # Clean up temporary files
        for temp_file_path in temp_files_to_clean:
            try:
                os.remove(temp_file_path)
            except OSError as e:
                print(f"Error deleting temp file {temp_file_path}: {e}")
        if os.path.exists(output_path):
             try:
                os.remove(output_path)
             except OSError as e:
                print(f"Error deleting output_path {output_path}: {e}")

        return public_url
    except Exception as e:
        print(f"Error in generate_video: {str(e)}")
        # Clean up temporary files in case of an error too
        for temp_file_path in temp_files_to_clean:
            try:
                os.remove(temp_file_path)
            except OSError as e:
                print(f"Error deleting temp file {temp_file_path} during error handling: {e}")
        return {"error": str(e)}

@app.post("/api/generate-video")
async def video_endpoint(
    file_urls: list[str] = Body(...),
    duration: int = Body(30),
    music_path: str = Body('sound/default_music.mp3'),
    title_text: str = Body("My Journey")
):
    media_file_paths = []
    try:
        for url in file_urls:
            response = requests.get(url)
            response.raise_for_status()
            suffix = os.path.splitext(url)[-1]
            temp = tempfile.NamedTemporaryFile(delete=False, suffix=suffix)
            temp.write(response.content)
            temp.close()
            media_file_paths.append(temp.name)

        public_url = generate_video(media_file_paths, duration, music_path, title_text)
        
        if isinstance(public_url, dict) and 'error' in public_url:
            return JSONResponse(content=public_url, status_code=500)
        return JSONResponse(content={"public_url": public_url})
    except requests.exceptions.RequestException as e:
        # Clean up any downloaded files if request fails
        for temp_file_path in media_file_paths:
            if os.path.exists(temp_file_path):
                try:
                    os.remove(temp_file_path)
                except OSError as ose:
                    print(f"Error deleting temp file {temp_file_path} during request exception: {ose}")
        return JSONResponse(content={"error": f"Failed to download file: {str(e)}"}, status_code=500)
    except Exception as e:
        # General error handling, also clean up temp files
        for temp_file_path in media_file_paths:
            if os.path.exists(temp_file_path):
                try:
                    os.remove(temp_file_path)
                except OSError as ose:
                    print(f"Error deleting temp file {temp_file_path} during general exception: {ose}")
        return JSONResponse(content={"error": str(e)}, status_code=500)

if __name__ == '__main__':
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=5000) 