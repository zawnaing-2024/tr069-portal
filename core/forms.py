from django import forms
from .models import ONU, CustomerInfo


class ONUForm(forms.ModelForm):
    """Form for creating and editing ONU records."""
    
    class Meta:
        model = ONU
        fields = [
            'serial_number', 'mac_address', 'ip_address',
            'vendor', 'model_name', 'firmware_version',
            'customer', 'online', 'rx_power', 'tx_power'
        ]
        widgets = {
            'serial_number': forms.TextInput(attrs={'class': 'form-control'}),
            'mac_address': forms.TextInput(attrs={'class': 'form-control', 'placeholder': 'AA:BB:CC:DD:EE:FF'}),
            'ip_address': forms.TextInput(attrs={'class': 'form-control', 'placeholder': '192.168.1.100'}),
            'vendor': forms.Select(attrs={'class': 'form-control'}),
            'model_name': forms.TextInput(attrs={'class': 'form-control'}),
            'firmware_version': forms.TextInput(attrs={'class': 'form-control'}),
            'customer': forms.Select(attrs={'class': 'form-control'}),
            'online': forms.CheckboxInput(attrs={'class': 'form-check-input'}),
            'rx_power': forms.NumberInput(attrs={'class': 'form-control', 'step': '0.01'}),
            'tx_power': forms.NumberInput(attrs={'class': 'form-control', 'step': '0.01'}),
        }


class CustomerForm(forms.ModelForm):
    """Form for creating and editing Customer records."""
    
    class Meta:
        model = CustomerInfo
        fields = ['name', 'phone', 'address', 'email', 'notes']
        widgets = {
            'name': forms.TextInput(attrs={'class': 'form-control'}),
            'phone': forms.TextInput(attrs={'class': 'form-control'}),
            'address': forms.Textarea(attrs={'class': 'form-control', 'rows': 3}),
            'email': forms.EmailInput(attrs={'class': 'form-control'}),
            'notes': forms.Textarea(attrs={'class': 'form-control', 'rows': 3}),
        } 