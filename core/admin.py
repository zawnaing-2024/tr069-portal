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
        "online",
        "last_inform",
        "customer",
    )
    list_filter = ("vendor", "online")
    search_fields = ("serial_number", "mac_address", "model_name") 