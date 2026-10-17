# Slim base = fewer OS packages = smaller attack surface and fewer CVEs.
# Pinned by digest (not just tag) so the image can't change underneath us.
# To update: docker buildx imagetools inspect python:3.12-slim
FROM python:3.12-slim@sha256:a6e34c598f2467ed0e9a8d349809fcd8b5c603269512df273a0bb1784edc11b1

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /app

# Install dependencies first (separate layer) so code changes don't bust the cache.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Dedicated unprivileged user. If the app is compromised, the attacker is not root.
RUN groupadd --system --gid 10001 app \
    && useradd --system --uid 10001 --gid app --no-create-home --shell /usr/sbin/nologin app

# Code is owned by root and only readable by the app user, so it can't modify itself.
COPY app.py .

USER 10001:10001

EXPOSE 8080

# slim has no curl, so use Python's stdlib to probe the health endpoint.
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD ["python", "-c", "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8080/health', timeout=2).status == 200 else 1)"]

# gunicorn is a production WSGI server (Flask's built-in server is dev-only).
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "2", "app:app"]
