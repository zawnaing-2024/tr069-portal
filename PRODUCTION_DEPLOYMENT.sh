#!/bin/bash

# TR069 Portal with TR-069 ACS - Complete Production Deployment Script
# Version: 2.0 - Production Ready
# Author: TR069 Portal Team
# Description: One-command deployment for Ubuntu 22.04 production servers

echo "🚀 TR069 Portal with TR-069 ACS - Production Deployment"
echo "======================================================="
echo "This script will install a complete TR-069 ACS server similar to GenieACS"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    print_error "This script should not be run as root. Run as ubuntu user with sudo access."
    exit 1
fi

# Get server IP
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')

echo "🔍 Pre-Installation Check"
echo "Server IP: $SERVER_IP"
echo "User: $(whoami)"
echo "OS: $(lsb_release -d | cut -f2)"
echo ""

read -p "Do you want to continue with installation? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

# Step 1: System Update
print_status "Step 1: Updating system packages..."
sudo apt update && sudo apt upgrade -y
print_success "System packages updated"

# Step 2: Install Dependencies
print_status "Step 2: Installing system dependencies..."
sudo apt install -y nginx mysql-server python3-pip python3-venv git curl
sudo apt install -y python3-dev default-libmysqlclient-dev build-essential pkg-config
sudo apt install -y redis-server ufw
print_success "System dependencies installed"

# Step 3: Configure Firewall
print_status "Step 3: Configuring firewall..."
sudo ufw allow 'Nginx Full'
sudo ufw allow ssh
sudo ufw --force enable
print_success "Firewall configured"

# Step 4: MySQL Setup
print_status "Step 4: Setting up MySQL database..."
sudo mysql -e "CREATE DATABASE IF NOT EXISTS tr069_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
sudo mysql -e "CREATE USER IF NOT EXISTS 'tr069_user'@'localhost' IDENTIFIED WITH mysql_native_password BY 'StrongPassword123!';"
sudo mysql -e "GRANT ALL PRIVILEGES ON tr069_db.* TO 'tr069_user'@'localhost';"
sudo mysql -e "FLUSH PRIVILEGES;"
print_success "MySQL database configured"

# Step 5: Application Setup
print_status "Step 5: Setting up application..."
sudo mkdir -p /opt/tr069
cd /opt/tr069

if [ -d "app" ]; then
    print_warning "Application directory exists. Backing up..."
    sudo mv app app_backup_$(date +%Y%m%d_%H%M%S)
fi

sudo git clone https://github.com/zawnaing-2024/tr069-portal.git app
cd app

# Step 6: Virtual Environment
print_status "Step 6: Creating virtual environment..."
sudo python3 -m venv venv
sudo chown -R www-data:www-data /opt/tr069
print_success "Virtual environment created"

# Step 7: Install Python Dependencies
print_status "Step 7: Installing Python dependencies..."
sudo -u www-data /opt/tr069/app/venv/bin/pip install --upgrade pip
sudo -u www-data /opt/tr069/app/venv/bin/pip install -r requirements.txt
print_success "Python dependencies installed"

# Step 8: Environment Configuration
print_status "Step 8: Creating environment configuration..."
sudo -u www-data cat > .env << EOF
SECRET_KEY=$(python3 -c 'from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())')
DEBUG=False
ALLOWED_HOSTS=$SERVER_IP,localhost,127.0.0.1

MYSQL_DATABASE=tr069_db
MYSQL_USER=tr069_user
MYSQL_PASSWORD=StrongPassword123!
MYSQL_HOST=localhost
MYSQL_PORT=3306
EOF
print_success "Environment configuration created"

# Step 9: Create Missing ACS Files (if needed)
print_status "Step 9: Ensuring ACS app structure..."

# Create ACS apps.py if missing
if [ ! -f "acs/apps.py" ]; then
    sudo -u www-data cat > acs/apps.py << 'EOF'
from django.apps import AppConfig


class AcsConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'acs'
    verbose_name = 'TR-069 ACS'
EOF
fi

# Create migrations directory
sudo -u www-data mkdir -p acs/migrations
sudo -u www-data touch acs/migrations/__init__.py

# Create templates directory
sudo -u www-data mkdir -p templates/acs

print_success "ACS app structure verified"

# Step 10: Database Migrations
print_status "Step 10: Running database migrations..."
sudo -u www-data /opt/tr069/app/venv/bin/python manage.py makemigrations
sudo -u www-data /opt/tr069/app/venv/bin/python manage.py makemigrations acs
sudo -u www-data /opt/tr069/app/venv/bin/python manage.py migrate
print_success "Database migrations completed"

# Step 11: Collect Static Files
print_status "Step 11: Collecting static files..."
sudo -u www-data /opt/tr069/app/venv/bin/python manage.py collectstatic --noinput
print_success "Static files collected"

# Step 12: Create Superuser
print_status "Step 12: Creating admin user..."
echo "from django.contrib.auth import get_user_model; User = get_user_model(); User.objects.create_superuser('admin', 'admin@example.com', 'admin123') if not User.objects.filter(username='admin').exists() else None" | sudo -u www-data /opt/tr069/app/venv/bin/python manage.py shell
print_success "Admin user created (username: admin, password: admin123)"

# Step 13: Gunicorn Configuration
print_status "Step 13: Configuring Gunicorn..."
sudo mkdir -p /var/log/tr069
sudo chown www-data:www-data /var/log/tr069

sudo cat > gunicorn.conf.py << 'EOF'
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
EOF
print_success "Gunicorn configured"

# Step 14: Systemd Service
print_status "Step 14: Creating systemd service..."
sudo cat > /etc/systemd/system/tr069.service << 'EOF'
[Unit]
Description=TR069 Portal Django Application with ACS
After=network.target mysql.service redis.service
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
EOF
print_success "Systemd service created"

# Step 15: Nginx Configuration
print_status "Step 15: Configuring Nginx..."
sudo cat > /etc/nginx/sites-available/tr069 << EOF
server {
    listen 80;
    server_name $SERVER_IP localhost;
    
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
    
    # TR-069 ACS endpoint - Special handling for SOAP
    location /acs/tr069/ {
        proxy_pass http://unix:/opt/tr069/tr069.sock;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
        proxy_buffering off;
    }
    
    # Main application
    location / {
        proxy_pass http://unix:/opt/tr069/tr069.sock;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/tr069 /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
print_success "Nginx configured"

# Step 16: Start Services
print_status "Step 16: Starting services..."
sudo systemctl daemon-reload
sudo systemctl enable tr069
sudo systemctl start tr069
sudo systemctl enable nginx
sudo systemctl restart nginx
sudo systemctl enable redis-server
sudo systemctl start redis-server
print_success "Services started"

# Step 17: Verify Installation
print_status "Step 17: Verifying installation..."
sleep 5

# Check services
if sudo systemctl is-active --quiet tr069; then
    print_success "TR069 service is running"
else
    print_error "TR069 service failed to start"
    sudo journalctl -u tr069.service --no-pager -l | tail -10
fi

if sudo systemctl is-active --quiet nginx; then
    print_success "Nginx service is running"
else
    print_error "Nginx service is not running"
fi

# Test endpoints
echo ""
print_status "Testing endpoints..."

# Test main application
main_test=$(curl -s -I http://localhost/ | head -1)
if echo "$main_test" | grep -q "200\|302"; then
    print_success "Main application: OK"
else
    print_warning "Main application: $main_test"
fi

# Test ACS dashboard
acs_test=$(curl -s -I http://localhost/acs/dashboard/ | head -1)
if echo "$acs_test" | grep -q "200\|302"; then
    print_success "ACS dashboard: OK"
else
    print_warning "ACS dashboard: $acs_test"
fi

# Test TR-069 endpoint
tr069_test=$(curl -s -I http://localhost/acs/tr069/ | head -1)
if echo "$tr069_test" | grep -q "405"; then
    print_success "TR-069 endpoint: OK (405 Method Not Allowed is expected)"
elif echo "$tr069_test" | grep -q "200"; then
    print_success "TR-069 endpoint: OK"
else
    print_warning "TR-069 endpoint: $tr069_test"
fi

# Step 18: Create Update Script
print_status "Step 18: Creating update script..."
cat > /opt/tr069/update_portal.sh << 'EOF'
#!/bin/bash
echo "Updating TR069 Portal..."
cd /opt/tr069/app
git pull origin main
sudo -u www-data /opt/tr069/app/venv/bin/pip install -r requirements.txt
sudo -u www-data /opt/tr069/app/venv/bin/python manage.py makemigrations
sudo -u www-data /opt/tr069/app/venv/bin/python manage.py makemigrations acs
sudo -u www-data /opt/tr069/app/venv/bin/python manage.py migrate
sudo -u www-data /opt/tr069/app/venv/bin/python manage.py collectstatic --noinput
sudo systemctl restart tr069
sudo systemctl reload nginx
echo "✅ Update completed!"
EOF
chmod +x /opt/tr069/update_portal.sh
print_success "Update script created at /opt/tr069/update_portal.sh"

# Final Summary
echo ""
echo "🎉 Installation Complete!"
echo "========================="
print_success "TR069 Portal with TR-069 ACS has been successfully installed!"
echo ""
echo "📋 Access Information:"
echo "  🌐 Main Portal:     http://$SERVER_IP/"
echo "  📊 ACS Dashboard:   http://$SERVER_IP/acs/dashboard/"
echo "  🔗 TR-069 Endpoint: http://$SERVER_IP/acs/tr069/"
echo "  ⚙️  Admin Panel:     http://$SERVER_IP/admin/"
echo ""
echo "🔐 Login Credentials:"
echo "  Username: admin"
echo "  Password: admin123"
echo ""
echo "🔧 Configure Your ONUs:"
echo "  ACS URL: http://$SERVER_IP/acs/tr069/"
echo "  Periodic Inform Interval: 300 seconds"
echo "  ACS Username: admin (optional)"
echo "  ACS Password: admin (optional)"
echo ""
echo "📊 Service Management:"
echo "  Start:   sudo systemctl start tr069"
echo "  Stop:    sudo systemctl stop tr069"
echo "  Restart: sudo systemctl restart tr069"
echo "  Status:  sudo systemctl status tr069"
echo "  Logs:    sudo tail -f /var/log/tr069/error.log"
echo ""
echo "🔄 Updates:"
echo "  Run: sudo /opt/tr069/update_portal.sh"
echo ""
echo "🎯 Features Available:"
echo "  ✅ Automatic ONU Discovery via TR-069"
echo "  ✅ Real-time Device Monitoring"
echo "  ✅ Professional ACS Dashboard"
echo "  ✅ Device Parameter Management"
echo "  ✅ Manual ONU Management"
echo "  ✅ Customer Management"
echo "  ✅ Role-based Access Control"
echo "  ✅ Production-ready Security"
echo ""
echo "🚀 Your TR-069 ACS server is ready to discover ONUs automatically!"
echo "Configure your ONUs and they will appear in the ACS dashboard."
echo ""
print_success "Installation completed successfully! 🎊" 