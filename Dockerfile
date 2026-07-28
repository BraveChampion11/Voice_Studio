FROM python:3.11-slim

RUN apt-get update && apt-get install -y \
    ffmpeg \
    git \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 1. Install base build tools
RUN pip install --no-cache-dir "pip<24.1" "setuptools<70" wheel cython

# 2. Install numpy early so subsequent packages can find it
RUN pip install --no-cache-dir "numpy==1.23.5"

# 3. Pull the massive PyTorch wheel first
RUN pip install --no-cache-dir --default-timeout=1000 torch==2.3.1

# 4. Install the RVC/fairseq chain WITHOUT letting pip resolve its old hydra-core pin
COPY requirements-rvc.txt .
RUN pip install --no-cache-dir --no-deps --no-build-isolation -r requirements-rvc.txt

# 5. Install everything else normally — f5-tts pulls its own hydra-core>=1.3.0
COPY requirements-core.txt .
RUN pip install --no-cache-dir --default-timeout=1000 --no-build-isolation -r requirements-core.txt

# Patch a known gradio_client bug: get_type() assumes schema is always a dict,
# but valid JSON Schema allows boolean sub-schemas (e.g. "additionalProperties": true)
RUN python3 -c "\
import re; \
path = '/usr/local/lib/python3.11/site-packages/gradio_client/utils.py'; \
content = open(path).read(); \
content = content.replace('def get_type(schema: dict):', 'def get_type(schema):\n    if isinstance(schema, bool):\n        return \"Any\"', 1); \
open(path, 'w').write(content)"

COPY . .
RUN mkdir -p saved_voices rvc_models training_data
EXPOSE 7860
CMD ["python", "app.py"]