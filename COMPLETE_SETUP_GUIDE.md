# Complete TR069 Portal with ACS Setup Guide

This is the master guide for setting up and configuring the TR069 Portal with automatic ONU discovery capabilities.

## 📚 Documentation Overview

This repository contains comprehensive guides for different scenarios:

### 🚀 **Fresh Installation** 
Use [`PRODUCTION_INSTALL_WITH_ACS.md`](./PRODUCTION_INSTALL_WITH_ACS.md) for:
- Complete Ubuntu 22.04 server setup
- MySQL database configuration
- Nginx web server setup
- TR-069 ACS implementation
- Production-ready deployment

### 🔄 **Updating Existing Installation**
Use [`ACS_UPDATE_GUIDE.md`](./ACS_UPDATE_GUIDE.md) for:
- Adding ACS functionality to existing portal
- Database migrations
- Template updates
- Service configuration

### 📱 **ONU Configuration**
Use [`ONU_CONFIGURATION_GUIDE.md`](./ONU_CONFIGURATION_GUIDE.md) for:
- Configuring ONUs to connect to ACS
- Brand-specific instructions (Huawei, ZTE, VSOL, etc.)
- Troubleshooting connection issues
- Verification steps

### 🔧 **Legacy Guides**
- [`PRODUCTION_INSTALL.md`](./PRODUCTION_INSTALL.md) - Original installation guide
- [`UPDATE.md`](./UPDATE.md) - General update procedures

## 🎯 Quick Start

### For New Installations:
1. **Follow:** [`PRODUCTION_INSTALL_WITH_ACS.md`](./PRODUCTION_INSTALL_WITH_ACS.md)
2. **Configure ONUs:** [`ONU_CONFIGURATION_GUIDE.md`](./ONU_CONFIGURATION_GUIDE.md)
3. **Result:** Fully functional TR-069 ACS with automatic device discovery

### For Existing Installations:
1. **Follow:** [`ACS_UPDATE_GUIDE.md`](./ACS_UPDATE_GUIDE.md)
2. **Configure ONUs:** [`ONU_CONFIGURATION_GUIDE.md`](./ONU_CONFIGURATION_GUIDE.md)
3. **Result:** Existing portal upgraded with ACS capabilities

## 🔍 What You'll Have

### **Core Features:**
- ✅ **Manual ONU Management** - Add, edit, delete ONUs with credentials
- ✅ **Customer Management** - Link customers to ONUs
- ✅ **Role-based Access** - Admin, Operator, Read-only dashboards
- ✅ **Professional UI** - Bootstrap-based responsive interface

### **NEW: ACS Features:**
- 🆕 **Automatic Device Discovery** - ONUs appear when they connect
- 🆕 **Real-time Monitoring** - Online/offline status updates
- 🆕 **TR-069 Protocol Support** - Full SOAP-based communication
- 🆕 **Device Parameter Management** - Track device configurations
- 🆕 **Integration** - Auto-creates ONU records from discovered devices

## 🌐 Access Points

After installation, you'll have these interfaces:

| Interface | URL | Purpose |
|-----------|-----|---------|
| **Main Portal** | `http://YOUR_SERVER_IP/` | Dashboard and ONU management |
| **ACS Dashboard** | `http://YOUR_SERVER_IP/acs/dashboard/` | Device discovery monitoring |
| **Admin Interface** | `http://YOUR_SERVER_IP/admin/` | Django admin panel |
| **TR-069 Endpoint** | `http://YOUR_SERVER_IP/acs/tr069/` | ONUs connect here |

## 🔧 Configuration Summary

### **Server Requirements:**
- Ubuntu 22.04 LTS
- Python 3.10+
- MySQL 8.0+
- Nginx
- 2GB+ RAM, 20GB+ storage

### **ONU Configuration:**
```
ACS URL: http://YOUR_SERVER_IP/acs/tr069/
Periodic Inform Interval: 300 seconds
ACS Username: admin (optional)
ACS Password: admin (optional)
```

## 📋 Installation Checklist

### Pre-Installation:
- [ ] Ubuntu 22.04 server ready
- [ ] Public IP or domain name available
- [ ] Root/sudo access confirmed
- [ ] Network connectivity tested

### Installation:
- [ ] **Database:** MySQL installed and configured
- [ ] **Application:** Code cloned and dependencies installed
- [ ] **Web Server:** Nginx configured and running
- [ ] **Services:** Django app running via gunicorn
- [ ] **ACS:** TR-069 endpoint responding
- [ ] **Templates:** ACS dashboard accessible

### Post-Installation:
- [ ] **Admin User:** Superuser account created
- [ ] **Test ONU:** At least one ONU configured and connected
- [ ] **Verification:** Device appears in ACS dashboard
- [ ] **Monitoring:** Real-time status updates working
- [ ] **Integration:** ONU record auto-created

## 🆘 Troubleshooting

### **Common Issues:**

| Problem | Solution Guide | Quick Fix |
|---------|---------------|-----------|
| Installation fails | [`PRODUCTION_INSTALL_WITH_ACS.md`](./PRODUCTION_INSTALL_WITH_ACS.md) | Check prerequisites |
| Update fails | [`ACS_UPDATE_GUIDE.md`](./ACS_UPDATE_GUIDE.md) | Backup first, then retry |
| ONU won't connect | [`ONU_CONFIGURATION_GUIDE.md`](./ONU_CONFIGURATION_GUIDE.md) | Verify ACS URL format |
| Services won't start | Check logs: `sudo journalctl -u tr069.service -f` | Restart services |

### **Log Locations:**
```bash
# Application logs
sudo tail -f /var/log/tr069/error.log

# Nginx logs  
sudo tail -f /var/log/nginx/error.log

# System logs
sudo journalctl -u tr069.service -f
```

## 🚀 Performance Optimization

### **For High Device Count:**
- Increase gunicorn workers: `workers = 5`
- Add Redis caching for device status
- Enable database indexing
- Consider load balancing

### **For Real-time Monitoring:**
- Set ONU inform interval to 60 seconds
- Enable WebSocket connections
- Use nginx as reverse proxy

## 🔐 Security Hardening

### **Production Checklist:**
- [ ] Change default SECRET_KEY
- [ ] Use strong database passwords  
- [ ] Enable HTTPS with SSL certificates
- [ ] Restrict admin interface access
- [ ] Monitor ACS endpoint for abuse
- [ ] Regular security updates

### **ONU Security:**
- [ ] Change default ONU passwords
- [ ] Use ACS authentication
- [ ] Restrict ONU management access
- [ ] Monitor unauthorized connections

## 📊 Monitoring & Maintenance

### **Daily Checks:**
```bash
# Service status
sudo systemctl status tr069 nginx mysql

# Disk space
df -h

# Active devices
curl -s http://localhost/acs/api/statistics/ | jq
```

### **Weekly Maintenance:**
```bash
# Update system packages
sudo apt update && sudo apt upgrade

# Clean old logs
sudo find /var/log -name "*.log" -mtime +30 -delete

# Database optimization
sudo mysqlcheck -u root -p --optimize --all-databases
```

## 🎉 Success Metrics

### **Your installation is successful when:**
- ✅ All services running without errors
- ✅ Web interface accessible from external networks
- ✅ ACS dashboard shows device statistics
- ✅ Test ONU appears automatically when configured
- ✅ Real-time status updates every 5 minutes
- ✅ ONU records created automatically
- ✅ Device parameters populated correctly

## 📞 Support Resources

### **Documentation Files:**
1. **Installation:** [`PRODUCTION_INSTALL_WITH_ACS.md`](./PRODUCTION_INSTALL_WITH_ACS.md)
2. **Updates:** [`ACS_UPDATE_GUIDE.md`](./ACS_UPDATE_GUIDE.md)  
3. **ONU Config:** [`ONU_CONFIGURATION_GUIDE.md`](./ONU_CONFIGURATION_GUIDE.md)
4. **Legacy Docs:** [`PRODUCTION_INSTALL.md`](./PRODUCTION_INSTALL.md), [`UPDATE.md`](./UPDATE.md)

### **Getting Help:**
1. **Check logs** for specific error messages
2. **Verify configuration** against the guides
3. **Test connectivity** between components
4. **Review prerequisites** for your specific setup

## 🎊 Congratulations!

Once everything is set up, you'll have a **professional TR-069 ACS server** that:
- Automatically discovers ONUs like GenieACS
- Monitors device status in real-time  
- Provides comprehensive management capabilities
- Scales to handle hundreds of devices
- Integrates seamlessly with your existing network

**Your ONUs will now automatically appear in the management portal when configured with your ACS URL!**

---

## 📋 Next Steps After Setup

1. **Configure your ONUs** with the ACS URL
2. **Test automatic discovery** with a few devices
3. **Set up user accounts** and permissions
4. **Configure monitoring** and alerting
5. **Scale up** with more ONUs
6. **Customize** the interface for your needs

**Welcome to automated ONU management!** 🚀 