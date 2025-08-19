# Use official Python image
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY vm_api.py .

# Expose FastAPI port
EXPOSE 8000

# Run with uvicorn
CMD ["uvicorn", "vm_api:app", "--host", "0.0.0.0", "--port", "8000"]
