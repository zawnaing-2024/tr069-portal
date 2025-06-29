from django.contrib import admin
from .models import DeviceInform, DeviceParameter, DeviceTask, DeviceSession, ACSConfig


@admin.register(DeviceInform)
class DeviceInformAdmin(admin.ModelAdmin):
    list_display = (
        'device_id', 'manufacturer', 'model_name', 'serial_number', 
        'ip_address', 'is_online', 'auto_discovered', 'last_inform', 'onu'
    )
    list_filter = ('is_online', 'auto_discovered', 'manufacturer', 'last_inform')
    search_fields = ('device_id', 'serial_number', 'manufacturer', 'model_name', 'ip_address')
    readonly_fields = ('device_id', 'first_contact', 'last_inform', 'auto_discovered')
    
    fieldsets = (
        ('Device Information', {
            'fields': ('device_id', 'oui', 'serial_number', 'product_class')
        }),
        ('Hardware Details', {
            'fields': ('manufacturer', 'model_name', 'software_version', 'hardware_version')
        }),
        ('Network Information', {
            'fields': ('ip_address', 'mac_address', 'connection_request_url')
        }),
        ('Status', {
            'fields': ('is_online', 'auto_discovered', 'first_contact', 'last_inform')
        }),
        ('ONU Link', {
            'fields': ('onu',),
            'classes': ('collapse',)
        }),
    )
    
    actions = ['mark_offline', 'mark_online', 'create_onu_records']
    
    def mark_offline(self, request, queryset):
        queryset.update(is_online=False)
        self.message_user(request, f"Marked {queryset.count()} devices as offline.")
    mark_offline.short_description = "Mark selected devices as offline"
    
    def mark_online(self, request, queryset):
        queryset.update(is_online=True)
        self.message_user(request, f"Marked {queryset.count()} devices as online.")
    mark_online.short_description = "Mark selected devices as online"
    
    def create_onu_records(self, request, queryset):
        created_count = 0
        for device in queryset:
            if not device.onu:
                device.create_onu_record()
                created_count += 1
        self.message_user(request, f"Created {created_count} ONU records.")
    create_onu_records.short_description = "Create ONU records for selected devices"


@admin.register(DeviceParameter)
class DeviceParameterAdmin(admin.ModelAdmin):
    list_display = ('device_inform', 'parameter_name', 'parameter_value', 'value_type', 'last_updated')
    list_filter = ('value_type', 'last_updated', 'device_inform__manufacturer')
    search_fields = ('parameter_name', 'parameter_value', 'device_inform__device_id')
    readonly_fields = ('last_updated',)
    
    def get_queryset(self, request):
        return super().get_queryset(request).select_related('device_inform')


@admin.register(DeviceTask)
class DeviceTaskAdmin(admin.ModelAdmin):
    list_display = (
        'device_inform', 'task_type', 'status', 'created_at', 'sent_at', 'completed_at'
    )
    list_filter = ('task_type', 'status', 'created_at')
    search_fields = ('device_inform__device_id', 'task_type', 'error_message')
    readonly_fields = ('created_at', 'sent_at', 'completed_at', 'result')
    
    fieldsets = (
        ('Task Information', {
            'fields': ('device_inform', 'task_type', 'parameters', 'status')
        }),
        ('Timestamps', {
            'fields': ('created_at', 'sent_at', 'completed_at')
        }),
        ('Results', {
            'fields': ('result', 'error_message'),
            'classes': ('collapse',)
        }),
    )
    
    actions = ['mark_as_pending', 'mark_as_failed']
    
    def mark_as_pending(self, request, queryset):
        queryset.update(status='pending')
        self.message_user(request, f"Marked {queryset.count()} tasks as pending.")
    mark_as_pending.short_description = "Mark selected tasks as pending"
    
    def mark_as_failed(self, request, queryset):
        queryset.update(status='failed')
        self.message_user(request, f"Marked {queryset.count()} tasks as failed.")
    mark_as_failed.short_description = "Mark selected tasks as failed"


@admin.register(DeviceSession)
class DeviceSessionAdmin(admin.ModelAdmin):
    list_display = ('session_id', 'device_id', 'ip_address', 'is_active', 'created_at', 'last_activity')
    list_filter = ('is_active', 'created_at', 'last_activity')
    search_fields = ('session_id', 'device_id', 'ip_address')
    readonly_fields = ('created_at', 'last_activity')
    
    actions = ['mark_inactive']
    
    def mark_inactive(self, request, queryset):
        queryset.update(is_active=False)
        self.message_user(request, f"Marked {queryset.count()} sessions as inactive.")
    mark_inactive.short_description = "Mark selected sessions as inactive"


@admin.register(ACSConfig)
class ACSConfigAdmin(admin.ModelAdmin):
    list_display = ('key', 'value', 'description', 'updated_at')
    search_fields = ('key', 'value', 'description')
    readonly_fields = ('updated_at',)
    
    fieldsets = (
        ('Configuration', {
            'fields': ('key', 'value', 'description')
        }),
        ('Metadata', {
            'fields': ('updated_at',),
            'classes': ('collapse',)
        }),
    ) 