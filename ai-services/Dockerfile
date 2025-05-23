FROM python:3.10-slim

# Install system dependencies
RUN apt-get update && \
    apt-get install -y ffmpeg imagemagick && \
    rm -rf /var/lib/apt/lists/*

# Fix ImageMagick security policy for MoviePy text overlays
RUN sed -i 's/<policy domain="coder" rights="none" pattern="MVG" \\/>/<\\!-- <policy domain="coder" rights="none" pattern="MVG" \\/> -->/g' /etc/ImageMagick-6/policy.xml || true

# Set work directory
WORKDIR /app

# Copy requirements and install
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the app code
COPY . .

# Expose the port
EXPOSE 5000

# Run the FastAPI app with Uvicorn
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "5000"] 