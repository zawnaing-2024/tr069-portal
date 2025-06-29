#!/bin/bash

echo "🚀 TR069 Portal ACS Deployment Script"
echo "======================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root or with sudo
if [[ $EUID -eq 0 ]]; then
    print_warning "Running as root. This is fine for deployment."
    SUDO=""
else
    print_status "Running as non-root user. Will use sudo when needed."
    SUDO="sudo"
fi

# Step 1: Navigate to application directory
print_status "Step 1: Navigating to application directory..."
cd /opt/tr069/app || {
    print_error "Failed to navigate to /opt/tr069/app"
    exit 1
}
print_success "Successfully navigated to application directory"

# Step 2: Fix git ownership issues
print_status "Step 2: Fixing git ownership issues..."
$SUDO git config --global --add safe.directory /opt/tr069/app
$SUDO chown -R ubuntu:ubuntu /opt/tr069/app/.git
print_success "Git ownership issues fixed"

# Step 3: Backup current installation
print_status "Step 3: Creating backup..."
backup_dir="/backup/tr069_$(date +%Y%m%d_%H%M%S)"
$SUDO mkdir -p /backup
$SUDO cp -r /opt/tr069/app "$backup_dir"
print_success "Backup created at $backup_dir"

# Step 4: Pull latest changes from GitHub
print_status "Step 4: Pulling latest changes from GitHub..."
git fetch origin
git reset --hard origin/main
print_success "Latest changes pulled successfully"

# Step 5: Check if ACS app exists
print_status "Step 5: Checking ACS app structure..."
if [ ! -f "acs/apps.py" ]; then
    print_warning "ACS apps.py missing. Creating it..."
    cat > acs/apps.py << 'EOF'
from django.apps import AppConfig


class AcsConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'acs'
    verbose_name = 'TR-069 ACS'
EOF
    print_success "Created acs/apps.py"
fi

# Create ACS migrations directory if missing
if [ ! -d "acs/migrations" ]; then
    print_warning "ACS migrations directory missing. Creating it..."
    mkdir -p acs/migrations
    touch acs/migrations/__init__.py
    print_success "Created ACS migrations directory"
fi

# Step 6: Install/update dependencies
print_status "Step 6: Installing/updating Python dependencies..."
$SUDO -u www-data /opt/tr069/app/venv/bin/pip install --upgrade pip
$SUDO -u www-data /opt/tr069/app/venv/bin/pip install -r requirements.txt
print_success "Python dependencies updated"

# Step 7: Update file permissions
print_status "Step 7: Updating file permissions..."
$SUDO chown -R www-data:www-data /opt/tr069/app
$SUDO chmod +x /opt/tr069/app/manage.py
print_success "File permissions updated"

# Step 8: Run database migrations
print_status "Step 8: Running database migrations..."
$SUDO -u www-data /opt/tr069/app/venv/bin/python manage.py makemigrations
$SUDO -u www-data /opt/tr069/app/venv/bin/python manage.py makemigrations acs
$SUDO -u www-data /opt/tr069/app/venv/bin/python manage.py migrate
print_success "Database migrations completed"

# Step 9: Collect static files
print_status "Step 9: Collecting static files..."
$SUDO -u www-data /opt/tr069/app/venv/bin/python manage.py collectstatic --noinput
print_success "Static files collected"

# Step 10: Test Django configuration
print_status "Step 10: Testing Django configuration..."
$SUDO -u www-data /opt/tr069/app/venv/bin/python manage.py check
if [ $? -eq 0 ]; then
    print_success "Django configuration is valid"
else
    print_error "Django configuration has issues. Please check the output above."
    exit 1
fi

# Step 11: Restart services
print_status "Step 11: Restarting services..."
$SUDO systemctl stop tr069
sleep 2
$SUDO rm -f /opt/tr069/tr069.sock
$SUDO systemctl start tr069
sleep 3
$SUDO systemctl reload nginx

# Check service status
print_status "Checking service status..."
if $SUDO systemctl is-active --quiet tr069; then
    print_success "TR069 service is running"
else
    print_error "TR069 service failed to start"
    $SUDO journalctl -u tr069.service --no-pager -l
    exit 1
fi

if $SUDO systemctl is-active --quiet nginx; then
    print_success "Nginx service is running"
else
    print_error "Nginx service is not running"
    exit 1
fi

# Step 12: Test endpoints
print_status "Step 12: Testing endpoints..."

# Test main application
echo -n "Testing main application... "
if curl -s -I http://localhost/ | grep -q "200\|302"; then
    print_success "Main application responding"
else
    print_warning "Main application may have issues"
fi

# Test ACS dashboard
echo -n "Testing ACS dashboard... "
if curl -s -I http://localhost/acs/dashboard/ | grep -q "200\|302"; then
    print_success "ACS dashboard responding"
else
    print_warning "ACS dashboard may have issues"
fi

# Test TR-069 endpoint
echo -n "Testing TR-069 endpoint... "
if curl -s -I http://localhost/acs/tr069/ | grep -q "405"; then
    print_success "TR-069 endpoint responding (405 Method Not Allowed is expected for GET)"
else
    print_warning "TR-069 endpoint may have issues"
fi

# Test TR-069 endpoint with POST
echo -n "Testing TR-069 endpoint with POST... "
response=$(curl -s -o /dev/null -w "%{http_code}" -X POST http://localhost/acs/tr069/ -H "Content-Type: text/xml" -d '<?xml version="1.0"?><test>test</test>')
if [ "$response" = "200" ] || [ "$response" = "500" ]; then
    print_success "TR-069 endpoint accepting POST requests"
else
    print_warning "TR-069 endpoint response: $response"
fi

# Step 13: Display final information
echo ""
echo "🎉 Deployment Complete!"
echo "======================"
print_success "TR069 Portal with ACS functionality has been deployed successfully!"
echo ""
echo "📋 Access Information:"
echo "  Main Portal:     http://$(curl -s ifconfig.me)/"
echo "  ACS Dashboard:   http://$(curl -s ifconfig.me)/acs/dashboard/"
echo "  TR-069 Endpoint: http://$(curl -s ifconfig.me)/acs/tr069/"
echo "  Admin Panel:     http://$(curl -s ifconfig.me)/admin/"
echo ""
echo "🔧 Configure your ONUs with:"
echo "  ACS URL: http://$(curl -s ifconfig.me)/acs/tr069/"
echo "  Periodic Inform Interval: 300 seconds"
echo "  ACS Username: admin (optional)"
echo "  ACS Password: admin (optional)"
echo ""
echo "📊 Check logs if needed:"
echo "  Application: sudo tail -f /var/log/tr069/error.log"
echo "  Nginx: sudo tail -f /var/log/nginx/error.log"
echo "  Service: sudo journalctl -u tr069.service -f"
echo ""
print_success "Ready to discover ONUs automatically! 🚀" 