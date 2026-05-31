FROM python:3.11-slim

WORKDIR /app

# Python modules
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Python source
COPY . .

# Godot Server
COPY ../game/bin/linux-x86_64.pck

EXPOSE 8000

CMD ["gunicorn", "--workers", "4", "--bind", "0.0.0.0:8000", "server:app"]
