# Python FastAPI server with dynamic container management
FROM python:3.12-slim

# Install system dependencies for psutil and Docker
RUN apt-get update && apt-get install -y \
    gcc \
    python3-dev \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy requirements first for better caching
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create directories for database and screenshots
RUN mkdir -p /app/data /app/screenshots /app/website_screenshots

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV USE_DOCKER=1

# Expose port
EXPOSE 8000

# Run the application
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]