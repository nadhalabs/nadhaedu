FROM python:3.13-slim AS runtime
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /srv/app
COPY pyproject.toml ./
COPY app ./app
RUN pip install --no-cache-dir .
COPY alembic ./alembic
COPY alembic.ini ./
USER 65532:65532
CMD ["sh","-c","alembic upgrade head && python -m app.seed_academics && exec uvicorn app.main:app --host 0.0.0.0 --port 8080 --proxy-headers"]
