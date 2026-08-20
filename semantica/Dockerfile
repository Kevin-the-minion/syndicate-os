FROM python:3.12-slim

WORKDIR /app

RUN pip install --no-cache-dir --quiet \
    semantica \
    fastapi \
    "uvicorn[standard]" \
    pydantic

COPY semantica-bridge.py /app/semantica-bridge.py

EXPOSE 8765

CMD ["python", "/app/semantica-bridge.py"]
