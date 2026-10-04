# Two stages so the runtime image has no Poetry or dev deps
FROM python:3.14-slim AS build
RUN pip install --no-cache-dir "poetry>=2,<3"
ENV POETRY_VIRTUALENVS_IN_PROJECT=1
WORKDIR /app
COPY pyproject.toml poetry.lock ./
RUN poetry install --only main --no-interaction

FROM python:3.14-slim
RUN useradd --no-log-init --uid 31337 appuser \
    && mkdir -p /app/data && chown appuser:appuser /app/data
WORKDIR /app
COPY --from=build /app/.venv ./.venv
COPY app ./app

ENV PATH="/app/.venv/bin:$PATH" \
    PYTHONDONTWRITEBYTECODE=1 \
    DATABASE_URL="sqlite:////app/data/user.db"
USER appuser

EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=3s \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/api/healthchecker')"

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
