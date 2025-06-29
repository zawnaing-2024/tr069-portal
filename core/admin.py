from django.contrib import admin
from .models import CustomerInfo, ONU

# Register your models here for future use. 

@admin.register(CustomerInfo)
class CustomerAdmin(admin.ModelAdmin):
    list_display = ("name", "phone", "email", "created_at")
    search_fields = ("name", "phone", "email")

@admin.register(ONU)
class ONUAdmin(admin.ModelAdmin):
    list_display = (
        "serial_number",
        "mac_address",
        "vendor",
        "model_name",
        "username",
        "online",
        "last_inform",
        "customer",
    )
    list_filter = ("vendor", "online")
    search_fields = ("serial_number", "mac_address", "model_name", "username")
    
    fieldsets = (
        ('Basic Information', {
            'fields': ('serial_number', 'mac_address', 'ip_address', 'vendor', 'model_name', 'firmware_version')
        }),
        ('Device Credentials', {
            'fields': ('username', 'password'),
            'classes': ('collapse',)
        }),
        ('Status & Monitoring', {
            'fields': ('online', 'last_inform', 'rx_power', 'tx_power')
        }),
        ('Customer', {
            'fields': ('customer',)
        }),
    ) 