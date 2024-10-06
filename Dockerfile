# Stage 1: Build
FROM nvidia/cuda:12.6.1-devel-ubuntu22.04 AS builder

# Install system dependencies
RUN apt-get update && apt-get install -y \
    python3-pip \
    python3-dev \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Set the working directory
WORKDIR /app

# Copy requirements file
COPY requirements.txt .

# Install Python dependencies
RUN pip3 install --no-cache-dir -r requirements.txt

# Install additional required packages
RUN pip3 install --no-cache-dir numpy==1.23.5 aiohttp pyyaml

# Install BitsandBytes for memory optimization
RUN pip3 install --no-cache-dir bitsandbytes

# Stage 2: Runtime
FROM nvidia/cuda:12.6.1-runtime-ubuntu22.04

# Install system dependencies
RUN apt-get update && apt-get install -y \
    python3-pip \
    python3-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Set the working directory
WORKDIR /app

# Copy files and installed Python packages from the builder stage
COPY --from=builder /usr/local/lib/python3.10/dist-packages /usr/local/lib/python3.10/dist-packages
COPY --from=builder /usr/local/bin /usr/local/bin

# Copy the application files
COPY . /app

# Set environment variable for BitsandBytes
ENV LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH

# Create a non-root user to run the application
RUN useradd -m comfyuser && chown -R comfyuser:comfyuser /app
USER comfyuser

# Expose the ComfyUI port
EXPOSE 8188

# Health check to monitor the service
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8188/ || exit 1

# Start the application in low VRAM mode
CMD ["python3", "main.py", "--listen", "0.0.0.0", "--port", "8188", "--lowvram"]
