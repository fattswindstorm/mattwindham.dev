FROM python:3.13-slim AS base

RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev --no-install-project

COPY . .
RUN uv sync --frozen --no-dev

RUN useradd --system --create-home appuser \
    && mkdir -p /app/staticfiles \
    && chown -R appuser:appuser /app

USER appuser

ENV PATH="/app/.venv/bin:$PATH"

EXPOSE 8000

# Migrations run at container start, not at build time - the DB isn't
# reachable during the CI build step, only once the task is actually
# running inside the VPC.
CMD ["sh", "-c", "python manage.py migrate --noinput && python manage.py collectstatic --noinput && gunicorn config.wsgi:application --bind 0.0.0.0:8000 --workers 2"]
