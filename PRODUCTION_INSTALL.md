# TR069 Portal - Production Installation Guide

This guide provides step-by-step instructions for setting up the TR069 Portal in a production environment with nginx, MySQL, and systemd.

## Prerequisites

- Ubuntu 22.04 LTS server
- Root or sudo access
- Public IP address or domain name

## Step 1: System Preparation

```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Install required system packages
sudo apt install -y nginx mysql-server python3-pip python3-venv git curl
sudo apt install -y python3-dev default-libmysqlclient-dev build-essential pkg-config
```

## Step 2: MySQL Database Setup

### Secure MySQL Installation
```bash
sudo mysql_secure_installation
```
Follow the prompts to secure your MySQL installation.

### Create Database and User
```bash
sudo mysql -u root -p
```

In MySQL console, run:
```sql
CREATE DATABASE tr069_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'tr069_user'@'localhost' IDENTIFIED WITH mysql_native_password BY 'StrongPassword123!';
GRANT ALL PRIVILEGES ON tr069_db.* TO 'tr069_user'@'localhost';
FLUSH PRIVILEGES;
EXIT;
```

**Note:** We use `mysql_native_password` to avoid cryptography package issues.

## Step 3: Application Setup

### Clone Repository and Setup Directory
```bash
sudo mkdir -p /opt/tr069
cd /opt/tr069
sudo git clone https://github.com/zawnaing-2024/tr069-portal.git app
cd app
```

### Create Virtual Environment
```bash
sudo python3 -m venv venv
sudo chown -R www-data:www-data /opt/tr069
```

### Install Python Dependencies
```bash
sudo -u www-data /opt/tr069/app/venv/bin/pip install --upgrade pip
sudo -u www-data /opt/tr069/app/venv/bin/pip install -r requirements.txt
# Install cryptography to avoid MySQL auth errors
sudo -u www-data /opt/tr069/app/venv/bin/pip install cryptography
```

## Step 4: Environment Configuration

### Create Environment File
```bash
sudo -u www-data nano /opt/tr069/app/.env
```

Add the following content (replace YOUR_IP with your server's public IP):
```env
SECRET_KEY=your-very-long-random-secret-key-change-this-in-production
DEBUG=False
ALLOWED_HOSTS=YOUR_SERVER_IP,localhost,127.0.0.1

MYSQL_DATABASE=tr069_db
MYSQL_USER=tr069_user
MYSQL_PASSWORD=StrongPassword123!
MYSQL_HOST=localhost
MYSQL_PORT=3306
```

### Update Django Settings for Production
```bash
sudo -u www-data nano /opt/tr069/app/tr069_portal/settings.py
```

Ensure the database configuration uses MySQL:
```python
# Database - Production MySQL Configuration
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.mysql',
        'NAME': env('MYSQL_DATABASE', default='tr069_db'),
        'USER': env('MYSQL_USER', default='tr069_user'),
        'PASSWORD': env('MYSQL_PASSWORD', default='StrongPassword123!'),
        'HOST': env('MYSQL_HOST', default='localhost'),
        'PORT': env('MYSQL_PORT', default='3306'),
        'OPTIONS': {
            'charset': 'utf8mb4',
            'init_command': "SET sql_mode='STRICT_TRANS_TABLES'",
        },
    }
}
```

## Step 5: Database Setup

### Run Migrations
```bash
cd /opt/tr069/app
sudo -u www-data /opt/tr069/app/venv/bin/python manage.py migrate
```

### Collect Static Files
```bash
sudo -u www-data /opt/tr069/app/venv/bin/python manage.py collectstatic --noinput
```

### Create Superuser
```bash
sudo -u www-data /opt/tr069/app/venv/bin/python manage.py createsuperuser
```

## Step 6: Gunicorn Configuration

### Create Log Directory
```bash
sudo mkdir -p /var/log/tr069
sudo chown www-data:www-data /var/log/tr069
```

### Create Gunicorn Config
```bash
sudo nano /opt/tr069/app/gunicorn.conf.py
```

Add the following content:
```python
bind = "unix:/opt/tr069/tr069.sock"
workers = 3
user = "www-data"
group = "www-data"
timeout = 30
keepalive = 2
max_requests = 1000
max_requests_jitter = 100
accesslog = "/var/log/tr069/access.log"
errorlog = "/var/log/tr069/error.log"
loglevel = "info"
```

## Step 7: Systemd Service Configuration

### Create Systemd Service File
```bash
sudo nano /etc/systemd/system/tr069.service
```

Add the following content:
```ini
[Unit]
Description=TR069 Portal Django Application
After=network.target mysql.service
Requires=mysql.service

[Service]
Type=notify
User=www-data
Group=www-data
WorkingDirectory=/opt/tr069/app
Environment=PATH=/opt/tr069/app/venv/bin
ExecStart=/opt/tr069/app/venv/bin/gunicorn --config /opt/tr069/app/gunicorn.conf.py tr069_portal.wsgi:application
ExecReload=/bin/kill -s HUP $MAINPID
Restart=always
RestartSec=10
KillMode=mixed
TimeoutStopSec=5
PrivateTmp=true

[Install]
WantedBy=multi-user.target
```

## Step 8: Nginx Configuration

### Create Nginx Site Configuration
```bash
sudo nano /etc/nginx/sites-available/tr069
```

Add the following content (replace YOUR_SERVER_IP):
```nginx
server {
    listen 80;
    server_name YOUR_SERVER_IP localhost;
    
    client_max_body_size 100M;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
    
    # Static files
    location /static/ {
        alias /opt/tr069/app/staticfiles/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # Media files
    location /media/ {
        alias /opt/tr069/app/media/;
        expires 1y;
        add_header Cache-Control "public";
    }
    
    # Main application
    location / {
        proxy_pass http://unix:/opt/tr069/tr069.sock;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
    }
}
```

### Enable Nginx Site
```bash
sudo ln -s /etc/nginx/sites-available/tr069 /etc/nginx/sites-enabled/ 2>/dev/null || true
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
```

## Step 9: Start Services

### Enable and Start Services
```bash
# Stop any existing services
sudo systemctl stop tr069 2>/dev/null || true
sudo rm -f /opt/tr069/tr069.sock

# Start services
sudo systemctl daemon-reload
sudo systemctl enable tr069
sudo systemctl start tr069
sudo systemctl enable nginx
sudo systemctl restart nginx
```

### Verify Services
```bash
sudo systemctl status tr069 --no-pager
sudo systemctl status nginx --no-pager
```

## Step 10: Firewall Configuration

```bash
# Configure UFW firewall
sudo ufw allow 'Nginx Full'
sudo ufw allow ssh
sudo ufw --force enable
sudo ufw status
```

## Step 11: Test Installation

### Test Local Access
```bash
curl -I http://localhost/
```
Expected response: `HTTP/1.1 302 Found` (redirect to login page)

### Test Public Access
```bash
curl -I http://YOUR_SERVER_IP/
```

### Get Access URL
```bash
echo "🚀 TR069 Portal is available at: http://$(curl -s ifconfig.me)/"
echo "🔐 Admin Panel: http://$(curl -s ifconfig.me)/admin/"
```

## Step 12: Create Update Script

```bash
sudo nano /opt/tr069/update.sh
```

Add the following content:
```bash
#!/bin/bash
echo "Starting TR069 Portal update..."
cd /opt/tr069/app

# Pull latest changes
git pull origin main

# Update Python packages
sudo -u www-data /opt/tr069/app/venv/bin/pip install -r requirements.txt
sudo -u www-data /opt/tr069/app/venv/bin/pip install cryptography

# Run database migrations
sudo -u www-data /opt/tr069/app/venv/bin/python manage.py migrate

# Collect static files
sudo -u www-data /opt/tr069/app/venv/bin/python manage.py collectstatic --noinput

# Restart services
sudo systemctl restart tr069
sudo systemctl reload nginx

echo "✅ Update completed successfully!"
echo "🚀 Access your portal at: http://$(curl -s ifconfig.me)/"
```

```bash
sudo chmod +x /opt/tr069/update.sh
```

## Troubleshooting

### Check Service Status
```bash
sudo systemctl status tr069
sudo journalctl -u tr069.service -f
```

### Check Logs
```bash
sudo tail -f /var/log/tr069/error.log
sudo tail -f /var/log/nginx/error.log
```

### Test Database Connection
```bash
cd /opt/tr069/app
sudo -u www-data /opt/tr069/app/venv/bin/python manage.py check --database default
```

### Common Issues and Solutions

1. **Cryptography Error**: Install cryptography package
   ```bash
   sudo -u www-data /opt/tr069/app/venv/bin/pip install cryptography
   ```

2. **Bad Request (400)**: Check ALLOWED_HOSTS in .env file

3. **Permission Denied**: Ensure www-data owns application files
   ```bash
   sudo chown -R www-data:www-data /opt/tr069
   ```

4. **Socket File Issues**: Remove and restart service
   ```bash
   sudo rm -f /opt/tr069/tr069.sock
   sudo systemctl restart tr069
   ```

## Features Available

- ✅ ONU Management with username/password credentials
- ✅ Customer Management and linking
- ✅ Role-based dashboards (Admin/Operator/Read-only)
- ✅ Secure password handling with show/hide functionality
- ✅ Search and filtering capabilities
- ✅ Production-ready with nginx and MySQL
- ✅ Automated deployment script

## Security Notes

- Change the SECRET_KEY in production
- Use strong database passwords
- Consider enabling HTTPS with SSL certificates
- Regularly update system packages and dependencies
- Monitor application logs for security issues

## Support

For issues or questions, check the troubleshooting section or review the application logs. 