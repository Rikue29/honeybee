from fastapi import FastAPI, UploadFile, File, Form
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

# Configure ImageMagick path for Windows
if os.name == 'nt':  # Windows
    IMAGEMAGICK_BINARY = r"C:\Program Files\ImageMagick-7.1.1-Q16-HDRI\magick.exe"
    if os.path.exists(IMAGEMAGICK_BINARY):
        change_settings({"IMAGEMAGICK_BINARY": IMAGEMAGICK_BINARY})

# Load environment variables
load_dotenv()

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

def resize_and_pad(clip, target_size=(720, 1280)):
    w, h = target_size

    def make_blur_frame(get_frame, t):
        frame = get_frame(t)
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

def generate_video(media_files, duration=30, music_path='sound/default_music.mp3', title_text="My Journey"):
    try:
        target_size = (720, 1280)  # Portrait for mobile
        clips = []
        for file in media_files:
            filename = file.filename.lower()
            with tempfile.NamedTemporaryFile(delete=False, suffix=os.path.splitext(filename)[-1]) as temp:
                content = file.file.read()
                temp.write(content)
                temp_path = temp.name
                file.file.seek(0)

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

            clip = resize_and_pad(clip, target_size)
            clips.append(clip)

        if not clips:
            raise ValueError("No valid media files provided")

        # Add title overlay to the first clip
        if title_text and clips:
            clips[0] = create_title_overlay(clips[0], title_text, target_size)

        final_clips = []
        for i, clip in enumerate(clips):
            if i > 0:
                clip = clip.crossfadein(1.0)
            final_clips.append(clip)

        # Add watermark at the end
        watermark = create_watermark(target_size)
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
            preset='ultrafast',  # <--- change here
            threads=4,
            ffmpeg_params=[
                '-pix_fmt', 'yuv420p',  # Required for iOS compatibility
                '-movflags', '+faststart',  # Enables streaming
                '-profile:v', 'high',  # High profile for better quality
                '-level', '4.0',  # Compatibility level
                '-crf', '23'  # Constant Rate Factor for quality
            ]
        )
        return output_path
    except Exception as e:
        print(f"Error in generate_video: {str(e)}")
        return {"error": str(e)}

@app.post("/api/generate-video")
async def video_endpoint(
    files: list[UploadFile] = File(...),
    duration: int = Form(30),
    music_path: str = Form('sound/default_music.mp3'),
    title_text: str = Form("My Journey")
):
    try:
        output_path = generate_video(files, duration, music_path, title_text)
        if isinstance(output_path, dict) and 'error' in output_path:
            return JSONResponse(content=output_path, status_code=500)
        return JSONResponse(content={"video_path": output_path})
    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)

if __name__ == '__main__':
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=5000) 