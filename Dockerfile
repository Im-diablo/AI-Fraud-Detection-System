# Use official lightweight Python image
FROM python:3.10-slim

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
RUN pip install --no-cache-dir --user -r requirements.txt

# Copy the rest of the application files
COPY --chown=user . $HOME/app/

# Expose port 8000 (standard port for web hosting services)
EXPOSE 8000

# Run the FastAPI app via Uvicorn (binds to PORT env variable if set, otherwise defaults to 8000)
CMD ["sh", "-c", "uvicorn app:app --host 0.0.0.0 --port ${PORT:-8000}"]
