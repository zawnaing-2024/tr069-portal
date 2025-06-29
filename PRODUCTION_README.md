# TR069 Portal with TR-069 ACS - Production Deployment Guide

🚀 **Professional TR-069 ACS Server - Similar to GenieACS**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Python 3.10+](https://img.shields.io/badge/python-3.10+-blue.svg)](https://www.python.org/downloads/)
[![Django 4.2](https://img.shields.io/badge/django-4.2-green.svg)](https://djangoproject.com/)

## 🎯 What This Provides

This is a **complete TR-069 ACS (Auto Configuration Server)** that automatically discovers and manages ONUs, similar to commercial solutions like GenieACS.

### ✨ Key Features

- ✅ **Automatic ONU Discovery** - Devices appear when they connect
- ✅ **Real-time Monitoring** - Live status updates every 5 minutes  
- ✅ **Professional Dashboard** - Beautiful web interface
- ✅ **Device Parameter Management** - Track and configure devices
- ✅ **Manual ONU Management** - Traditional device management
- ✅ **Customer Management** - Link devices to customers
- ✅ **Role-based Access** - Admin, Operator, Read-only levels
- ✅ **Production Ready** - Nginx, MySQL, systemd integration
- ✅ **SOAP Protocol Support** - Full TR-069 compliance
- ✅ **Scalable Architecture** - Handles hundreds of devices

## 🚀 One-Command Installation

### For Fresh Ubuntu 22.04 Server:

```bash
# 1. Clone repository
git clone https://github.com/zawnaing-2024/tr069-portal.git
cd tr069-portal

# 2. Run production deployment (one command!)
chmod +x PRODUCTION_DEPLOYMENT.sh
./PRODUCTION_DEPLOYMENT.sh
```

**That's it!** The script automatically installs and configures everything.

### What Gets Installed:

- ✅ **System packages** (Python, MySQL, Nginx, Redis)
- ✅ **Database setup** with proper user and permissions
- ✅ **Application deployment** with virtual environment
- ✅ **Web server configuration** with SSL-ready nginx
- ✅ **System services** with automatic startup
- ✅ **Security configuration** with firewall setup
- ✅ **Admin user creation** (username: admin, password: admin123)

## 📋 System Requirements

### Server Specifications:
- **OS:** Ubuntu 22.04 LTS (recommended)
- **RAM:** 2GB minimum, 4GB recommended
- **Storage:** 20GB minimum, 50GB recommended
- **Network:** Public IP or domain name
- **Ports:** 80 (HTTP), 443 (HTTPS optional), 22 (SSH)

### Supported ONU Brands:
- ✅ **Huawei** (HG8010H, HG8240H, HG8245H, etc.)
- ✅ **ZTE** (F601, F609, F660, F680, etc.)
- ✅ **VSOL** (V2801, V2802, V2801R, etc.)
- ✅ **Fiberhome** (AN5506, HG110, etc.)
- ✅ **Any TR-069 compliant device**

## 🌐 After Installation Access

Once installation completes, access your server:

| Interface | URL | Purpose |
|-----------|-----|---------|
| **Main Portal** | `http://YOUR_SERVER_IP/` | Dashboard and ONU management |
| **ACS Dashboard** | `http://YOUR_SERVER_IP/acs/dashboard/` | Auto-discovered devices |
| **Admin Panel** | `http://YOUR_SERVER_IP/admin/` | System administration |
| **TR-069 Endpoint** | `http://YOUR_SERVER_IP/acs/tr069/` | ONUs connect here |

### 🔐 Default Login:
- **Username:** `admin`
- **Password:** `admin123`

## 🔧 Configure Your ONUs

After installation, configure your ONUs with these settings:

```
ACS URL: http://YOUR_SERVER_IP/acs/tr069/
Periodic Inform Interval: 300 seconds (5 minutes)
ACS Username: admin (optional)
ACS Password: admin (optional)
```

### 📱 Quick Configuration Examples:

#### Huawei ONUs:
1. Access ONU: `http://192.168.1.1`
2. Login: `admin/admin`
3. Go to: **System Tools** → **Remote Management**
4. Set ACS URL and enable periodic inform

#### ZTE ONUs:
1. Access ONU: `http://192.168.1.1`
2. Login: `admin/admin`
3. Go to: **Network** → **Remote Management** → **TR-069**
4. Configure ACS settings

#### VSOL ONUs:
1. Access ONU: `http://192.168.1.1`
2. Login: `admin/admin`
3. Go to: **Management** → **TR069**
4. Enable and configure ACS

**📖 Detailed configuration guides available in:** [`ONU_CONFIGURATION_GUIDE.md`](./ONU_CONFIGURATION_GUIDE.md)

## 📊 What You'll See

### ACS Dashboard Features:
- 📈 **Real-time Statistics** - Total, online, offline devices
- 🔍 **Device Discovery** - Automatic appearance of new ONUs
- 📋 **Device Information** - Manufacturer, model, IP, status
- ⚡ **Live Updates** - Status changes every 5 minutes
- 🔗 **Integration** - Links to manual ONU management

### Manual Management Features:
- 👥 **Customer Management** - Add and link customers
- 🌐 **ONU Management** - Manual device addition/editing
- 📊 **Optical Power Monitoring** - Signal strength tracking
- 🎛️ **Role-based Dashboards** - Different views per user type

## 🔄 Management Commands

### Service Management:
```bash
# Check status
sudo systemctl status tr069

# Start/stop services
sudo systemctl start tr069
sudo systemctl stop tr069
sudo systemctl restart tr069

# View logs
sudo tail -f /var/log/tr069/error.log
sudo journalctl -u tr069.service -f
```

### Updates:
```bash
# Update to latest version
sudo /opt/tr069/update_portal.sh

# Manual update
cd /opt/tr069/app
git pull origin main
sudo systemctl restart tr069
```

## 🛠️ Advanced Configuration

### Custom Domain Setup:
```bash
# Update nginx configuration
sudo nano /etc/nginx/sites-available/tr069

# Add your domain to server_name
server_name yourdomain.com YOUR_SERVER_IP;

# Restart nginx
sudo systemctl restart nginx
```

### SSL Certificate (Let's Encrypt):
```bash
# Install certbot
sudo apt install certbot python3-certbot-nginx

# Get certificate
sudo certbot --nginx -d yourdomain.com

# Auto-renewal is configured automatically
```

### Database Backup:
```bash
# Create backup
sudo mysqldump tr069_db > backup_$(date +%Y%m%d).sql

# Restore backup
sudo mysql tr069_db < backup_file.sql
```

## 🔐 Security Features

### Built-in Security:
- ✅ **User Authentication** - Login required for all access
- ✅ **Role-based Access Control** - Multiple permission levels
- ✅ **CSRF Protection** - Secure form submissions
- ✅ **Security Headers** - XSS, content-type protection
- ✅ **Firewall Configuration** - UFW with minimal ports
- ✅ **Database Security** - Dedicated user with limited permissions

### Production Hardening:
```bash
# Change default admin password
# Login to admin panel and update password

# Update secret key
sudo nano /opt/tr069/app/.env
# Change SECRET_KEY to new random value

# Restart services
sudo systemctl restart tr069
```

## 📈 Scalability

### Performance Optimization:
- **Gunicorn Workers:** Adjust in `/opt/tr069/app/gunicorn.conf.py`
- **Database Optimization:** MySQL tuning for large datasets  
- **Caching:** Redis integration for faster responses
- **Load Balancing:** Multiple server support

### Monitoring:
```bash
# Resource usage
htop
df -h
free -h

# Application metrics
curl http://localhost/acs/api/statistics/
```

## 🆘 Troubleshooting

### Common Issues:

#### 1. Service Won't Start
```bash
# Check logs
sudo journalctl -u tr069.service --no-pager -l

# Check configuration
sudo -u www-data /opt/tr069/app/venv/bin/python manage.py check

# Fix permissions
sudo chown -R www-data:www-data /opt/tr069/app
```

#### 2. ONUs Not Appearing
```bash
# Check TR-069 endpoint
curl -I http://localhost/acs/tr069/

# Should return: 405 Method Not Allowed (this is correct!)

# Check ONU configuration:
# - ACS URL format: http://SERVER_IP/acs/tr069/
# - Periodic inform enabled
# - Network connectivity
```

#### 3. Database Connection Issues
```bash
# Test database connection
sudo mysql -u tr069_user -p tr069_db

# Check credentials in .env file
cat /opt/tr069/app/.env
```

#### 4. Nginx Issues
```bash
# Test nginx configuration
sudo nginx -t

# Check error logs
sudo tail -f /var/log/nginx/error.log

# Restart nginx
sudo systemctl restart nginx
```

## 📚 Complete Documentation

This repository includes comprehensive guides:

| Guide | Purpose | Use Case |
|-------|---------|----------|
| [`PRODUCTION_DEPLOYMENT.sh`](./PRODUCTION_DEPLOYMENT.sh) | **One-command install** | Fresh server setup |
| [`PRODUCTION_INSTALL_WITH_ACS.md`](./PRODUCTION_INSTALL_WITH_ACS.md) | **Step-by-step guide** | Manual installation |
| [`ACS_UPDATE_GUIDE.md`](./ACS_UPDATE_GUIDE.md) | **Upgrade existing** | Add ACS to current portal |
| [`ONU_CONFIGURATION_GUIDE.md`](./ONU_CONFIGURATION_GUIDE.md) | **Device setup** | Configure ONUs to connect |
| [`COMPLETE_SETUP_GUIDE.md`](./COMPLETE_SETUP_GUIDE.md) | **Master guide** | Overview and navigation |

## 🎯 Use Cases

### Perfect For:
- 🏢 **ISP Operations** - Manage customer ONUs automatically
- 🌐 **Network Monitoring** - Real-time device status tracking
- ⚙️ **Device Provisioning** - Automatic configuration management
- 🎧 **Customer Support** - Quick device information access
- 📦 **Inventory Management** - Track devices and customers
- 🔧 **Troubleshooting** - Monitor optical power and connectivity

### Industry Applications:
- **Fiber Internet Service Providers**
- **Enterprise Network Management**
- **Building Management Systems**
- **Telecommunications Infrastructure**
- **Smart City Projects**

## 🌟 Why Choose This Over GenieACS?

| Feature | TR069 Portal | GenieACS |
|---------|-------------|-----------|
| **Web Interface** | ✅ Professional, modern | ❌ Basic, dated |
| **Customer Management** | ✅ Built-in CRM features | ❌ Not included |
| **Installation** | ✅ One-command setup | ❌ Complex configuration |
| **ONU Management** | ✅ Manual + automatic | ✅ Automatic only |
| **User Roles** | ✅ Multi-level access | ❌ Limited |
| **Documentation** | ✅ Comprehensive guides | ❌ Minimal |
| **Cost** | ✅ Free and open source | ✅ Free |
| **Support** | ✅ Community + docs | ❌ Community only |

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is open source and available under the MIT License.

## 🎊 Success!

After installation, you'll have:

- 🚀 **Professional TR-069 ACS server** running and ready
- 📊 **Beautiful web dashboard** for monitoring devices
- ⚡ **Automatic ONU discovery** when devices connect
- 🔧 **Complete management tools** for customers and devices
- 📚 **Comprehensive documentation** for operations
- 🔐 **Production-ready security** and performance

**Transform your ONU management with automatic discovery today!**

---

*Built with ❤️ for network administrators and ISP operators who want GenieACS-like functionality with a professional interface.*

## 📞 Support

- 📖 **Documentation:** Complete guides included
- 🔍 **Troubleshooting:** Step-by-step solutions
- 🌐 **Repository:** [GitHub Issues](https://github.com/zawnaing-2024/tr069-portal/issues)
- 💬 **Community:** Share experiences and solutions

**Ready to get started? Run the installation script and have your TR-069 ACS server running in minutes!** 🚀 