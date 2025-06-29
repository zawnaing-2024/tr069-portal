from django.db import models
from django.utils import timezone
from core.models import ONU, CustomerInfo
import json


class DeviceSession(models.Model):
    """Track TR-069 sessions with devices"""
    session_id = models.CharField(max_length=128, unique=True)
    device_id = models.CharField(max_length=256)  # Device OUI-Serial
    ip_address = models.GenericIPAddressField()
    user_agent = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    last_activity = models.DateTimeField(auto_now=True)
    is_active = models.BooleanField(default=True)
    
    class Meta:
        db_table = 'acs_device_session'
    
    def __str__(self):
        return f"Session {self.session_id} - {self.device_id}"


class DeviceInform(models.Model):
    """Store device inform messages for auto-discovery"""
    device_id = models.CharField(max_length=256)
    oui = models.CharField(max_length=6)  # Organizationally Unique Identifier
    serial_number = models.CharField(max_length=64)
    product_class = models.CharField(max_length=64, blank=True)
    manufacturer = models.CharField(max_length=64, blank=True)
    model_name = models.CharField(max_length=64, blank=True)
    software_version = models.CharField(max_length=64, blank=True)
    hardware_version = models.CharField(max_length=64, blank=True)
    
    # Network Information
    ip_address = models.GenericIPAddressField()
    mac_address = models.CharField(max_length=17, blank=True)
    connection_request_url = models.URLField(max_length=512, blank=True)
    
    # Status
    is_online = models.BooleanField(default=True)
    last_inform = models.DateTimeField(auto_now=True)
    first_contact = models.DateTimeField(auto_now_add=True)
    
    # Auto-discovered device (not manually added)
    auto_discovered = models.BooleanField(default=True)
    onu = models.OneToOneField(ONU, on_delete=models.CASCADE, null=True, blank=True)
    
    class Meta:
        db_table = 'acs_device_inform'
        unique_together = ['oui', 'serial_number']
    
    def __str__(self):
        return f"{self.device_id} ({self.manufacturer} {self.model_name})"
    
    def create_onu_record(self):
        """Automatically create ONU record from discovered device"""
        if not self.onu:
            # Determine vendor from OUI or manufacturer
            vendor = "Other"
            if self.manufacturer:
                manufacturer_lower = str(self.manufacturer).lower()
                if "huawei" in manufacturer_lower:
                    vendor = "Huawei"
                elif "zte" in manufacturer_lower:
                    vendor = "ZTE"
            
            # Create ONU record
            onu = ONU.objects.create(
                serial_number=self.serial_number,
                mac_address=self.mac_address or f"00:00:00:00:00:00",  # Placeholder
                ip_address=self.ip_address,
                vendor=vendor,
                model_name=self.model_name or "Unknown",
                firmware_version=self.software_version or "",
                online=self.is_online,
                last_inform=self.last_inform
            )
            self.onu = onu
            self.save()
            return onu
        return self.onu


class DeviceParameter(models.Model):
    """Store device parameters from TR-069"""
    device_inform = models.ForeignKey(DeviceInform, on_delete=models.CASCADE, related_name='parameters')
    parameter_name = models.CharField(max_length=512)
    parameter_value = models.TextField()
    value_type = models.CharField(max_length=20, default='string')  # string, int, boolean
    last_updated = models.DateTimeField(auto_now=True)
    
    class Meta:
        db_table = 'acs_device_parameter'
        unique_together = ['device_inform', 'parameter_name']
    
    def __str__(self):
        return f"{self.device_inform.device_id}: {self.parameter_name}"


class DeviceTask(models.Model):
    """Queue tasks to be sent to devices"""
    TASK_TYPES = [
        ('GetParameterValues', 'Get Parameter Values'),
        ('SetParameterValues', 'Set Parameter Values'),
        ('Reboot', 'Reboot Device'),
        ('FactoryReset', 'Factory Reset'),
        ('Download', 'Firmware Download'),
    ]
    
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('sent', 'Sent'),
        ('completed', 'Completed'),
        ('failed', 'Failed'),
    ]
    
    device_inform = models.ForeignKey(DeviceInform, on_delete=models.CASCADE, related_name='tasks')
    task_type = models.CharField(max_length=20, choices=TASK_TYPES)
    parameters = models.JSONField(default=dict)  # Task parameters
    status = models.CharField(max_length=10, choices=STATUS_CHOICES, default='pending')
    created_at = models.DateTimeField(auto_now_add=True)
    sent_at = models.DateTimeField(null=True, blank=True)
    completed_at = models.DateTimeField(null=True, blank=True)
    result = models.JSONField(default=dict)
    error_message = models.TextField(blank=True)
    
    class Meta:
        db_table = 'acs_device_task'
        ordering = ['-created_at']
    
    def __str__(self):
        return f"{self.device_inform.device_id}: {self.task_type} ({self.status})"


class ACSConfig(models.Model):
    """ACS Configuration settings"""
    key = models.CharField(max_length=100, unique=True)
    value = models.TextField()
    description = models.TextField(blank=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        db_table = 'acs_config'
    
    def __str__(self):
        return f"{self.key}: {self.value}"
    
    @classmethod
    def get_setting(cls, key, default=None):
        try:
            return cls.objects.get(key=key).value
        except cls.DoesNotExist:
            return default
    
    @classmethod
    def set_setting(cls, key, value, description=""):
        obj, created = cls.objects.get_or_create(
            key=key,
            defaults={'value': value, 'description': description}
        )
        if not created:
            obj.value = value
            obj.description = description
            obj.save()
        return obj 