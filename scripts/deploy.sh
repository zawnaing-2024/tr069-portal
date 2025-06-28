#!/usr/bin/env bash
# deploy.sh – pulls latest code, installs deps, migrates, collects static, reloads gunicorn
set -euo pipefail

APP_DIR="/opt/tr069/app"
VENV="$APP_DIR/venv"
PY="$VENV/bin/python"
PIP="$VENV/bin/pip"

echo "► Pulling latest code..."
git -C "$APP_DIR" fetch --all
LATEST_COMMIT=$(git -C "$APP_DIR" rev-parse origin/main)
git -C "$APP_DIR" checkout "$LATEST_COMMIT"

echo "Current version: $LATEST_COMMIT"

echo "► Installing Python packages..."
"$PIP" install -r "$APP_DIR/requirements.txt"

echo "► Applying migrations..."
"$PY" "$APP_DIR/manage.py" migrate --noinput

echo "► Collecting static files..."
"$PY" "$APP_DIR/manage.py" collectstatic --noinput

echo "► Reloading Gunicorn..."
if systemctl is-active --quiet tr069; then
  systemctl reload tr069
else
  echo "Gunicorn not running, starting service..."
  systemctl start tr069
fi

echo "✓ Deploy complete" 