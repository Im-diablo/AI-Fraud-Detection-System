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
    libgl1-mesa-glx \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Switch back to the non-root user
USER user

# Copy requirements and install dependencies
COPY --chown=user requirements.txt $HOME/app/
RUN pip install --no-cache-dir --user -r requirements.txt

# Copy the rest of the application files
COPY --chown=user . $HOME/app/

# Expose port 7860 (the port Hugging Face Spaces expects)
EXPOSE 7860

# Run the FastAPI app via Uvicorn
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "7860"]
