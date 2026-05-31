FROM python:3.11-slim

WORKDIR /app

# Python modules
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Python source
COPY . .

CMD ["gunicorn", "--workers", "4", "--bind", "0.0.0.0:8000", "server:app"]
