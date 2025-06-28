from django.db import models
from django.core.validators import RegexValidator, MinValueValidator, MaxValueValidator

# Models to be implemented in next steps:
# class ONU(...)
# class CustomerInfo(...) 

class CustomerInfo(models.Model):
    """Stores customer / subscriber details linked to an ONU."""

    name = models.CharField(max_length=255)
    phone = models.CharField(max_length=20, blank=True)
    address = models.TextField(blank=True)
    email = models.EmailField(blank=True)

    notes = models.TextField(blank=True, help_text="Internal notes (not shown to customer)")

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "Customer"
        verbose_name_plural = "Customers"

    def __str__(self):
        return f"{self.name} ({self.phone})" if self.phone else self.name


VENDOR_CHOICES = (
    ("Huawei", "Huawei"),
    ("ZTE", "ZTE"),
    ("Other", "Other"),
)


mac_validator = RegexValidator(
    regex=r"^([0-9A-Fa-f]{2}[:\-]){5}([0-9A-Fa-f]{2})$",
    message="Enter a valid MAC address (e.g. AA:BB:CC:DD:EE:FF)",
)


class ONU(models.Model):
    """Represents an Optical Network Unit (CPE)."""

    serial_number = models.CharField(max_length=64, unique=True)
    mac_address = models.CharField(max_length=17, unique=True, validators=[mac_validator])
    ip_address = models.GenericIPAddressField(protocol="IPv4", blank=True, null=True)

    vendor = models.CharField(max_length=16, choices=VENDOR_CHOICES, default="Other")
    model_name = models.CharField(max_length=64, blank=True)
    firmware_version = models.CharField(max_length=64, blank=True)

    customer = models.ForeignKey(
        CustomerInfo, related_name="onus", on_delete=models.SET_NULL, null=True, blank=True
    )

    # live status fields
    online = models.BooleanField(default=False)
    last_inform = models.DateTimeField(null=True, blank=True)

    # optical power (dBm). Acceptable range typically -30 to +5
    rx_power = models.DecimalField(
        max_digits=5, decimal_places=2, null=True, blank=True,
        validators=[MinValueValidator(-40), MaxValueValidator(10)],
    )
    tx_power = models.DecimalField(
        max_digits=5, decimal_places=2, null=True, blank=True,
        validators=[MinValueValidator(-40), MaxValueValidator(10)],
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["serial_number"]

    def __str__(self):
        return f"{self.serial_number} ({self.vendor})" 