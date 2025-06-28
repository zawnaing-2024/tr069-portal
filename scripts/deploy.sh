#!/usr/bin/env bash
# deploy.sh – pulls latest code, installs deps, migrates, collects static, reloads gunicorn
set -euo pipefail

APP_DIR="/opt/tr069/app"
VENV="$APP_DIR/venv"
PY="$VENV/bin/python"
PIP="$VENV/bin/pip"

# 1. Update code
echo "► Pulling latest code…"
git -C "$APP_DIR" fetch --all
LATEST_COMMIT=$(git -C "$APP_DIR" rev-parse origin/main)
git -C "$APP_DIR" checkout "$LATEST_COMMIT"

echo "Current version: $LATEST_COMMIT"

# 2. Install any new deps
echo "► Installing Python packages…"
"$PIP" install -r "$APP_DIR/requirements.txt"

# 3. Database migrations
echo "► Applying migrations…"
"$PY" "$APP_DIR/manage.py" migrate --noinput

# 4. Collect static
"$PY" "$APP_DIR/manage.py" collectstatic --noinput

# 5. Reload gunicorn via systemd (zero downtime)
SYSTEMD_UNIT="tr069"

echo "► Reloading Gunicorn…"
if systemctl is-active --quiet "$SYSTEMD_UNIT"; then
  systemctl reload "$SYSTEMD_UNIT"
else
  echo "Gunicorn not running, starting service…"
  systemctl start "$SYSTEMD_UNIT"
fi

echo "✓ Deploy complete" 