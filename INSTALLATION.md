# TR-069 Portal Installation Guide

Complete step-by-step guide to deploy the Django TR-069 portal from Windows development to Ubuntu 22.04 production.

## Prerequisites

### Windows Development Machine
- Python 3.10+ (with "Add to PATH" checked)
- Git for Windows (with "Git Bash" and "Add to PATH")
- VS Code (optional but recommended)

### Ubuntu 22.04 Server
- Fresh Ubuntu 22.04 LTS server
- Root access or sudo privileges
- Internet connection

## Part 1: Windows Development Setup

### 1.1 Clone Repository
```powershell
# Create project directory
mkdir C:\Projects\tr069
cd C:\Projects\tr069

# Clone the repository
git clone https://github.com/YOUR_USERNAME/tr069-portal.git .
```

### 1.2 Python Virtual Environment
```powershell
# Create virtual environment
python -m venv venv

# Activate virtual environment
.\venv\Scripts\Activate.ps1

# Install dependencies
pip install -r requirements.txt
```

### 1.3 Local Development (SQLite)
```powershell
# Run migrations
python manage.py migrate

# Create superuser
python manage.py createsuperuser

# Start development server
python manage.py runserver
```

Visit `http://127.0.0.1:8000` to test locally.

### 1.4 Git Workflow
```powershell
# Configure Git (first time only)
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# Daily workflow
git add .
git commit -m "your changes"
git push origin main
```

## Part 2: Ubuntu Production Installation

### 2.1 Initial Server Setup
```bash
# Update system
apt update && apt upgrade -y

# Install required packages
apt install -y python3 python3-venv python3-pip git ufw nginx mysql-server

# Configure firewall
ufw allow OpenSSH
ufw allow 'Nginx Full'
ufw --force enable
```

### 2.2 Create Application User
```bash
# Create dedicated user
adduser --system --group --home /opt/tr069 tr069

# Create application directory
mkdir -p /opt/tr069/app
```

### 2.3 Clone Repository
```bash
# Clone to application directory
cd /opt/tr069
git clone https://github.com/YOUR_USERNAME/tr069-portal.git app
chown -R tr069:tr069 /opt/tr069
```

### 2.4 Python Environment Setup
```bash
# Create virtual environment
sudo -u tr069 -H python3 -m venv /opt/tr069/app/venv

# Upgrade pip
sudo -u tr069 -H /opt/tr069/app/venv/bin/pip install --upgrade pip

# Install dependencies (including cryptography for MySQL)
sudo -u tr069 -H /opt/tr069/app/venv/bin/pip install -r /opt/tr069/app/requirements.txt
sudo -u tr069 -H /opt/tr069/app/venv/bin/pip install cryptography
```

### 2.5 MySQL Database Setup
```bash
# Create database and user
mysql -e "CREATE DATABASE IF NOT EXISTS tr069 CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -e "CREATE USER IF NOT EXISTS 'tr069_app'@'localhost' IDENTIFIED BY 'tr069_pass';"
mysql -e "GRANT ALL PRIVILEGES ON tr069.* TO 'tr069_app'@'localhost'; FLUSH PRIVILEGES;"

# Optional: Use older authentication method if needed
mysql -e "ALTER USER 'tr069_app'@'localhost' IDENTIFIED WITH mysql_native_password BY 'tr069_pass';"
mysql -e "FLUSH PRIVILEGES;"
```

### 2.6 Django Configuration
```bash
# Create production .env file
sudo -u tr069 -H tee /opt/tr069/app/.env >/dev/null <<EOF
SECRET_KEY=your-very-long-random-secret-key-here
DEBUG=False
ALLOWED_HOSTS=*

MYSQL_DATABASE=tr069
MYSQL_USER=tr069_app
MYSQL_PASSWORD=tr069_pass
MYSQL_HOST=127.0.0.1
MYSQL_PORT=3306
EOF
```

### 2.7 Django Database Setup
```bash
# Run migrations
sudo -u tr069 -H /opt/tr069/app/venv/bin/python /opt/tr069/app/manage.py migrate --noinput

# Collect static files
sudo -u tr069 -H /opt/tr069/app/venv/bin/python /opt/tr069/app/manage.py collectstatic --noinput

# Create superuser (interactive)
sudo -u tr069 -H /opt/tr069/app/venv/bin/python /opt/tr069/app/manage.py createsuperuser
```

### 2.8 Gunicorn Service Setup
```bash
# Create systemd service file
tee /etc/systemd/system/tr069.service >/dev/null <<'EOF'
[Unit]
Description=Django TR-069 Portal
After=network.target

[Service]
User=tr069
Group=tr069
WorkingDirectory=/opt/tr069/app
EnvironmentFile=/opt/tr069/app/.env

ExecStart=/opt/tr069/app/venv/bin/gunicorn \
          --workers 3 \
          --bind unix:/opt/tr069/tr069.sock \
          tr069_portal.wsgi:application

ExecReload=/bin/kill -s HUP $MAINPID
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Enable and start service
systemctl daemon-reload
systemctl enable tr069
systemctl start tr069
systemctl status tr069 --no-pager
```

### 2.9 Nginx Configuration
```bash
# Create Nginx site configuration
tee /etc/nginx/sites-available/tr069 >/dev/null <<'EOF'
server {
    listen 80;
    server_name _;

    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-Content-Type-Options "nosniff";

    location /static/ {
        alias /opt/tr069/app/static/;
    }

    location /media/ {
        alias /opt/tr069/app/media/;
    }

    location / {
        proxy_pass http://unix:/opt/tr069/tr069.sock;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

# Remove default site and enable our site
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/tr069 /etc/nginx/sites-enabled/tr069

# Test and reload Nginx
nginx -t && systemctl reload nginx
systemctl status nginx --no-pager
```

### 2.10 Verification
```bash
# Check services
systemctl status tr069 --no-pager
systemctl status nginx --no-pager

# Check socket file
ls -l /opt/tr069/tr069.sock

# Check user
id tr069
```

Visit `http://YOUR_SERVER_IP/` - you should see the Django login page.

## Part 3: Deployment Workflow

### 3.1 Create Deploy Script
```bash
# Create deployment script
tee /opt/tr069/deploy.sh >/dev/null <<'EOF'
#!/usr/bin/env bash
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
EOF

# Make executable
chmod +x /opt/tr069/deploy.sh
```

### 3.2 Daily Update Process
```bash
# From Windows: push changes to GitHub
git add .
git commit -m "your changes"
git push origin main

# On Ubuntu server: deploy changes
ssh tr069@YOUR_SERVER_IP
sudo /opt/tr069/deploy.sh
```

## Part 4: Troubleshooting

### 4.1 Common Issues

**Service won't start:**
```bash
journalctl -u tr069 -n 20 --no-pager
```

**Nginx shows default page:**
```bash
rm -f /etc/nginx/sites-enabled/default
systemctl reload nginx
```

**Database connection errors:**
```bash
# Test MySQL connection
mysql -u tr069_app -p tr069
```

**Permission errors:**
```bash
chown -R tr069:tr069 /opt/tr069
```

### 4.2 Log Locations
- Gunicorn logs: `journalctl -u tr069 -f`
- Nginx logs: `/var/log/nginx/error.log`
- Django logs: Application logs (if configured)

### 4.3 Service Management
```bash
# Start/stop/restart services
systemctl start|stop|restart tr069
systemctl start|stop|restart nginx

# Check status
systemctl status tr069
systemctl status nginx

# View logs
journalctl -u tr069 -f
journalctl -u nginx -f
```

## Part 5: Security Considerations

### 5.1 Production Hardening
- Change default passwords
- Configure proper `ALLOWED_HOSTS` in Django settings
- Set up SSL/TLS certificates
- Configure proper firewall rules
- Regular security updates

### 5.2 Backup Strategy
```bash
# Database backup
mysqldump tr069 | gzip > /var/backups/tr069-$(date +%F).sql.gz

# Application backup
tar -czf /var/backups/tr069-app-$(date +%F).tar.gz /opt/tr069/app
```

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review service logs
3. Verify all services are running
4. Check file permissions

---

**Installation Complete!** 

Your TR-069 portal should now be accessible at `http://YOUR_SERVER_IP/` 