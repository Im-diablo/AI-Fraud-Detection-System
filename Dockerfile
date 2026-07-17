# Use official lightweight Python image
FROM python:3.12-slim

# Create a non-root user (Hugging Face Spaces runs as user 1000 by default)
RUN useradd -m -u 1000 user
ENV HOME=/home/user \
    PATH=/home/user/.local/bin:$PATH

WORKDIR $HOME/app

# Install system dependencies needed by OpenCV and PIL (graphics/image libraries)
# We temporarily switch to root to run apt-get
USER root
RUN apt-get update && apt-get install -y \
    libgl1 \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Switch back to the non-root user
USER user

# Copy requirements and install dependencies
COPY --chown=user requirements.txt $HOME/app/

# Install PyTorch CPU first to prevent downloading heavy CUDA binaries (reduces image size from 3GB to <500MB)
RUN pip install --no-cache-dir --user torch torchvision --index-url https://download.pytorch.org/whl/cpu

# Install the remaining dependencies
RUN pip install --no-cache-dir --user -r requirements.txt

# Copy the rest of the application files
COPY --chown=user . $HOME/app/

# Create models directory with correct ownership before running the download script
USER root
RUN mkdir -p $HOME/app/models && chown -R user:user $HOME/app
USER user

# Download and extract the models during the build phase (bakes models into the image)
# Using -u for unbuffered output so all print statements appear in build logs
RUN python -u download_models.py || { echo "=== DOWNLOAD FAILED ===" && exit 1; }

# Expose port 8000 (standard port for web hosting services)
EXPOSE 8000

# Run the FastAPI app via Uvicorn (binds to PORT env variable if set, otherwise defaults to 8000)
CMD ["sh", "-c", "uvicorn app:app --host 0.0.0.0 --port ${PORT:-8000}"]
