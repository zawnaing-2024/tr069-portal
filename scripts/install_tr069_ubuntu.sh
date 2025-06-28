#!/usr/bin/env bash
# ============================================================
# install_tr069_ubuntu.sh
# One-shot installer for the Django TR-069 portal on Ubuntu 22.04
# Must be run as root (sudo -i).
# ============================================================
set -euo pipefail

if [[ $(id -u) -ne 0 ]]; then
    echo "ERROR: Please run this script as root (sudo -i)." >&2
    exit 1
fi

PORTAL_USER="tr069"
PORTAL_HOME="/opt/tr069"
APP_DIR="$PORTAL_HOME/app"
REPO_URL="https://example.com/your-git-repo.git"  # <-- change me
DB_NAME="tr069"
DB_USER="tr069_app"
DB_PASS="tr069_pass"
DJANGO_SECRET_KEY="$(tr -dc A-Za-z0-9 </dev/urandom | head -c 64)"

# 1. Update system and install packages
apt update && apt upgrade -y
apt install -y python3 python3-venv python3-pip git ufw nginx mysql-server

# 2. Firewall basic rules
ufw allow OpenSSH
ufw allow 'Nginx Full'
ufw --force enable

# 3. Create dedicated system user
adduser --system --group --home "$PORTAL_HOME" "$PORTAL_USER" || true

# 4. Clone repository
sudo -u "$PORTAL_USER" -H git clone "$REPO_URL" "$APP_DIR"

# 5. Python virtual environment
sudo -u "$PORTAL_USER" -H python3 -m venv "$APP_DIR/venv"
sudo -u "$PORTAL_USER" -H "$APP_DIR/venv/bin/pip" install --upgrade pip
sudo -u "$PORTAL_USER" -H "$APP_DIR/venv/bin/pip" install -r "$APP_DIR/requirements.txt"

# 6. MySQL secure install (skipped interactive) and DB user
mysql -e "CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -e "CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
mysql -e "GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost'; FLUSH PRIVILEGES;"

# 7. .env production file
sudo -u "$PORTAL_USER" -H tee "$APP_DIR/.env" >/dev/null <<EOF
SECRET_KEY=$DJANGO_SECRET_KEY
DEBUG=False
ALLOWED_HOSTS=*

MYSQL_DATABASE=$DB_NAME
MYSQL_USER=$DB_USER
MYSQL_PASSWORD=$DB_PASS
MYSQL_HOST=127.0.0.1
MYSQL_PORT=3306
EOF

# 8. Django migrate & collectstatic
sudo -u "$PORTAL_USER" -H "$APP_DIR/venv/bin/python" "$APP_DIR/manage.py" migrate --noinput
sudo -u "$PORTAL_USER" -H "$APP_DIR/venv/bin/python" "$APP_DIR/manage.py" collectstatic --noinput

# 9. Ask for superuser creation (interactive)
echo "Creating Django superuser. Provide username/email/password when prompted."
sudo -u "$PORTAL_USER" -H "$APP_DIR/venv/bin/python" "$APP_DIR/manage.py" createsuperuser

# 10. Install systemd service
cp "$APP_DIR/scripts/tr069.service" /etc/systemd/system/tr069.service
systemctl daemon-reload
systemctl enable tr069
systemctl start tr069

# 11. Install Nginx site
cp "$APP_DIR/scripts/nginx_tr069.conf" /etc/nginx/sites-available/tr069
ln -sf /etc/nginx/sites-available/tr069 /etc/nginx/sites-enabled/tr069
nginx -t && systemctl reload nginx

echo "\n============================================================"
echo "TR-069 portal deployed! Visit your server's IP to log in."
echo "============================================================" 