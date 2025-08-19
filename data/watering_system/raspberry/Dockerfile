FROM python:3.11-slim

# Create app dir
WORKDIR /app

# System deps (optional, keeps image minimal)
RUN apt-get update && apt-get install -y --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

# Python deps
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# App
COPY mediator.py .

# Data volume for persistent registry
VOLUME ["/data"]

# Environment defaults (override at runtime)
ENV LOCAL_BROKER_HOST=raspberrypi \
    LOCAL_BROKER_PORT=1883 \
    VM_BROKER_HOST=vm-broker-host \
    VM_BROKER_PORT=1883 \
    VM_BASE_PREFIX=devices \
    REGISTRY_PATH=/data/devices.json \
    RPC_TIMEOUT=8

# Run forever
CMD ["python", "mediator.py"]
