FROM python:3.12-slim

WORKDIR /app

RUN pip install --no-cache-dir --quiet fastapi "uvicorn[standard]" pydantic

COPY app.py /app/app.py

EXPOSE 8080

CMD ["python", "/app/app.py"]
