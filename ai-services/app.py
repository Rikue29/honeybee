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

def resize_and_pad(clip, target_size=(720, 1280)):
    """
    Resizes and pads a clip to the target_size (default portrait 720x1280).
    For landscape clips, it will scale to fill height and center-crop width.
    For portrait clips, it will scale to fit within target_size.
    Background is a blurred version of the clip.
    """    
    target_w, target_h = target_size

    if hasattr(clip, 'img'):
        original_frame_rgb = clip.img
        original_h, original_w = original_frame_rgb.shape[:2]
        is_image = True
    else:
        # For videos, we might need to get a sample frame to determine dimensions accurately if clip.size is not enough
        # However, clip.size should generally be correct for videos.
        original_w, original_h = clip.size
        is_image = False
        # Create a sample frame for blurring for videos
        # Taking a frame from near the middle of the video, or first if too short
        sample_time = min(clip.duration / 2, 0.1) if clip.duration > 0 else 0
        original_frame_rgb = clip.get_frame(sample_time)

    original_frame_bgr = cv2.cvtColor(original_frame_rgb, cv2.COLOR_RGB2BGR)

    # Create a blurred background matching the target size
    blurred_bg_bgr = cv2.resize(original_frame_bgr, (target_w, target_h))
    blurred_bg_bgr = cv2.GaussianBlur(blurred_bg_bgr, (99, 99), 30)

    # Handle landscape media (original_w > original_h)
    if original_w > original_h:
        # Scale to fit target height, then center crop width
        scale_ratio = target_h / original_h
        scaled_w = int(original_w * scale_ratio)
        scaled_h = target_h # int(original_h * scale_ratio) which is target_h
        
        resized_frame_bgr = cv2.resize(original_frame_bgr, (scaled_w, scaled_h))
        
        # Crop width if necessary
        if scaled_w > target_w:
            crop_x = (scaled_w - target_w) // 2
            cropped_frame_bgr = resized_frame_bgr[:, crop_x:crop_x + target_w]
        else:
            # This case should ideally not happen if original was landscape and we scaled to target_h
            # But if it does (e.g. original aspect very wide but not tall enough after scaling), pad width
            cropped_frame_bgr = cv2.copyMakeBorder(
                resized_frame_bgr, 0, 0, 
                (target_w - scaled_w) // 2, (target_w - scaled_w + 1) // 2, 
                cv2.BORDER_CONSTANT, value=[0,0,0]
            )
        final_fg_bgr = cropped_frame_bgr
        # The foreground is already at target_w, target_h (or should be close)
        # We composite this onto the blurred_bg_bgr. Since it's a center crop, x_offset and y_offset are 0.
        final_composited_bgr = blurred_bg_bgr # Start with blurred bg
        # Ensure fg is exactly target_w x target_h for direct placement
        final_fg_bgr_resized = cv2.resize(final_fg_bgr, (target_w, target_h)) 
        final_composited_bgr[0:target_h, 0:target_w] = final_fg_bgr_resized

    # Handle portrait or square media (original_w <= original_h)
    else:
        # Scale to fit within target_w, target_h while maintaining aspect ratio
        scale_w_ratio = target_w / original_w
        scale_h_ratio = target_h / original_h
        scale_ratio = min(scale_w_ratio, scale_h_ratio)

        scaled_w = int(original_w * scale_ratio)
        scaled_h = int(original_h * scale_ratio)

        resized_frame_bgr = cv2.resize(original_frame_bgr, (scaled_w, scaled_h))
        
        # Calculate padding
        pad_x = (target_w - scaled_w) // 2
        pad_y = (target_h - scaled_h) // 2

        final_composited_bgr = blurred_bg_bgr # Start with blurred_bg
        final_composited_bgr[pad_y:pad_y + scaled_h, pad_x:pad_x + scaled_w] = resized_frame_bgr
    
    final_composited_rgb = cv2.cvtColor(final_composited_bgr, cv2.COLOR_BGR2RGB)

    if is_image:
        return ImageClip(final_composited_rgb).set_duration(clip.duration)
    else:
        # For videos, we need a function that applies this transformation to each frame
        def transform_frame(get_frame, t):
            frame_rgb = get_frame(t)
            frame_bgr = cv2.cvtColor(frame_rgb, cv2.COLOR_RGB2BGR)
            original_h_f, original_w_f = frame_rgb.shape[:2]

            # Background (can be pre-calculated or use a static blurred image from first frame)
            # For simplicity here, re-using the initial blurred_bg_bgr derived from a sample frame.
            # A more robust solution might blur each frame or use the pre-calculated blurred_bg_rgb.
            current_blurred_bg_bgr = cv2.resize(frame_bgr, (target_w, target_h))
            current_blurred_bg_bgr = cv2.GaussianBlur(current_blurred_bg_bgr, (99,99), 30)

            if original_w_f > original_h_f: # Landscape frame
                s_ratio = target_h / original_h_f
                s_w, s_h = int(original_w_f * s_ratio), target_h
                resized_f_bgr = cv2.resize(frame_bgr, (s_w, s_h))
                if s_w > target_w:
                    crop_x_f = (s_w - target_w) // 2
                    cropped_f_bgr = resized_f_bgr[:, crop_x_f:crop_x_f + target_w]
                else:
                    cropped_f_bgr = cv2.copyMakeBorder(resized_f_bgr, 0, 0, (target_w - s_w) // 2, (target_w - s_w + 1) // 2, cv2.BORDER_CONSTANT, value=[0,0,0])
                
                final_f_bgr_resized = cv2.resize(cropped_f_bgr, (target_w, target_h))
                # Composite onto blurred background
                composited_f_bgr = current_blurred_bg_bgr
                composited_f_bgr[0:target_h, 0:target_w] = final_f_bgr_resized
            else: # Portrait or square frame
                s_w_ratio = target_w / original_w_f
                s_h_ratio = target_h / original_h_f
                s_ratio = min(s_w_ratio, s_h_ratio)
                s_w, s_h = int(original_w_f * s_ratio), int(original_h_f * s_ratio)
                resized_f_bgr = cv2.resize(frame_bgr, (s_w, s_h))
                p_x = (target_w - s_w) // 2
                p_y = (target_h - s_h) // 2
                composited_f_bgr = current_blurred_bg_bgr
                composited_f_bgr[p_y:p_y + s_h, p_x:p_x + s_w] = resized_f_bgr
            
            return cv2.cvtColor(composited_f_bgr, cv2.COLOR_BGR2RGB)
        
        return clip.fl(transform_frame).set_duration(clip.duration)

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