FROM python:3.11-slim

WORKDIR /app

# Since context is now the backend folder, requirements is right here
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy all source files from the current backend folder into the container
COPY . .

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]