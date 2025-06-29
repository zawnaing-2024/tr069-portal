"""
TR-069 Protocol Handler
Handles SOAP-based communication with CPE devices
"""

import xml.etree.ElementTree as ET
from xml.dom import minidom
import uuid
from datetime import datetime
from django.http import HttpResponse
from django.views.decorators.csrf import csrf_exempt
from django.utils.decorators import method_decorator
from django.views import View
import logging

logger = logging.getLogger(__name__)

# TR-069 SOAP Namespaces
SOAP_ENV = "http://schemas.xmlsoap.org/soap/envelope/"
SOAP_ENC = "http://schemas.xmlsoap.org/soap/encoding/"
CWMP_NS = "urn:dslforum-org:cwmp-1-0"

class TR069Handler:
    """Handle TR-069 SOAP messages"""
    
    def __init__(self):
        self.session_id = None
        self.device_id = None
        
    def parse_inform(self, xml_data):
        """Parse CWMP Inform message"""
        try:
            root = ET.fromstring(xml_data)
            
            # Find Inform element
            inform = root.find('.//ns:Inform', {'ns': CWMP_NS})
            if inform is None:
                return None
                
            device_id = inform.find('.//DeviceId', {'ns': CWMP_NS})
            event_struct = inform.find('.//Event', {'ns': CWMP_NS})
            param_list = inform.find('.//ParameterList', {'ns': CWMP_NS})
            
            # Extract device information
            device_info = {}
            if device_id is not None:
                for child in device_id:
                    device_info[child.tag] = child.text
                    
            # Extract events
            events = []
            if event_struct is not None:
                for event in event_struct.findall('.//EventStruct'):
                    event_code = event.find('EventCode')
                    command_key = event.find('CommandKey')
                    events.append({
                        'EventCode': event_code.text if event_code is not None else '',
                        'CommandKey': command_key.text if command_key is not None else ''
                    })
            
            # Extract parameters
            parameters = {}
            if param_list is not None:
                for param in param_list.findall('.//ParameterValueStruct'):
                    name = param.find('Name')
                    value = param.find('Value')
                    if name is not None and value is not None:
                        parameters[name.text] = value.text
                        
            return {
                'device_info': device_info,
                'events': events,
                'parameters': parameters
            }
            
        except ET.ParseError as e:
            logger.error(f"XML Parse Error: {e}")
            return None
    
    def create_inform_response(self, max_envelopes=1):
        """Create InformResponse SOAP message"""
        envelope = ET.Element("{%s}Envelope" % SOAP_ENV)
        envelope.set("xmlns:soap", SOAP_ENV)
        envelope.set("xmlns:cwmp", CWMP_NS)
        
        header = ET.SubElement(envelope, "{%s}Header" % SOAP_ENV)
        body = ET.SubElement(envelope, "{%s}Body" % SOAP_ENV)
        
        inform_response = ET.SubElement(body, "{%s}InformResponse" % CWMP_NS)
        max_env = ET.SubElement(inform_response, "MaxEnvelopes")
        max_env.text = str(max_envelopes)
        
        return self._prettify_xml(envelope)
    
    def create_get_parameter_values(self, parameter_names):
        """Create GetParameterValues SOAP message"""
        envelope = ET.Element("{%s}Envelope" % SOAP_ENV)
        envelope.set("xmlns:soap", SOAP_ENV)
        envelope.set("xmlns:cwmp", CWMP_NS)
        
        header = ET.SubElement(envelope, "{%s}Header" % SOAP_ENV)
        id_elem = ET.SubElement(header, "{%s}ID" % CWMP_NS)
        id_elem.text = str(uuid.uuid4())
        
        body = ET.SubElement(envelope, "{%s}Body" % SOAP_ENV)
        get_param = ET.SubElement(body, "{%s}GetParameterValues" % CWMP_NS)
        
        param_names = ET.SubElement(get_param, "ParameterNames")
        for name in parameter_names:
            param = ET.SubElement(param_names, "string")
            param.text = name
            
        return self._prettify_xml(envelope)
    
    def create_set_parameter_values(self, parameters):
        """Create SetParameterValues SOAP message"""
        envelope = ET.Element("{%s}Envelope" % SOAP_ENV)
        envelope.set("xmlns:soap", SOAP_ENV)
        envelope.set("xmlns:cwmp", CWMP_NS)
        
        header = ET.SubElement(envelope, "{%s}Header" % SOAP_ENV)
        id_elem = ET.SubElement(header, "{%s}ID" % CWMP_NS)
        id_elem.text = str(uuid.uuid4())
        
        body = ET.SubElement(envelope, "{%s}Body" % SOAP_ENV)
        set_param = ET.SubElement(body, "{%s}SetParameterValues" % CWMP_NS)
        
        param_list = ET.SubElement(set_param, "ParameterList")
        for name, value in parameters.items():
            param_struct = ET.SubElement(param_list, "ParameterValueStruct")
            name_elem = ET.SubElement(param_struct, "Name")
            name_elem.text = name
            value_elem = ET.SubElement(param_struct, "Value")
            value_elem.text = str(value)
            
        param_key = ET.SubElement(set_param, "ParameterKey")
        param_key.text = str(uuid.uuid4())
        
        return self._prettify_xml(envelope)
    
    def create_reboot(self, command_key=""):
        """Create Reboot SOAP message"""
        envelope = ET.Element("{%s}Envelope" % SOAP_ENV)
        envelope.set("xmlns:soap", SOAP_ENV)
        envelope.set("xmlns:cwmp", CWMP_NS)
        
        header = ET.SubElement(envelope, "{%s}Header" % SOAP_ENV)
        id_elem = ET.SubElement(header, "{%s}ID" % CWMP_NS)
        id_elem.text = str(uuid.uuid4())
        
        body = ET.SubElement(envelope, "{%s}Body" % SOAP_ENV)
        reboot = ET.SubElement(body, "{%s}Reboot" % CWMP_NS)
        
        cmd_key = ET.SubElement(reboot, "CommandKey")
        cmd_key.text = command_key
        
        return self._prettify_xml(envelope)
    
    def _prettify_xml(self, element):
        """Return a pretty-printed XML string"""
        rough_string = ET.tostring(element, 'unicode')
        reparsed = minidom.parseString(rough_string)
        return reparsed.toprettyxml(indent="  ")


@method_decorator(csrf_exempt, name='dispatch')
class TR069ACSView(View):
    """Main TR-069 ACS endpoint"""
    
    def __init__(self):
        super().__init__()
        self.tr069_handler = TR069Handler()
    
    def post(self, request):
        """Handle TR-069 SOAP requests"""
        try:
            # Get client IP
            client_ip = self.get_client_ip(request)
            
            # Parse SOAP content
            soap_data = request.body.decode('utf-8')
            logger.info(f"Received TR-069 request from {client_ip}")
            logger.debug(f"SOAP Data: {soap_data}")
            
            # Parse Inform message
            parsed_data = self.tr069_handler.parse_inform(soap_data)
            
            if parsed_data:
                # Handle device discovery
                self.handle_device_discovery(parsed_data, client_ip, request)
                
                # Create InformResponse
                response_xml = self.tr069_handler.create_inform_response()
                
                return HttpResponse(
                    response_xml.encode('utf-8'),
                    content_type='text/xml; charset=utf-8',
                    status=200
                )
            else:
                # Handle other SOAP messages (responses, etc.)
                return self.handle_other_soap_messages(soap_data, request)
                
        except Exception as e:
            logger.error(f"TR-069 Handler Error: {e}")
            return HttpResponse(
                self.create_soap_fault("Server", str(e)).encode('utf-8'),
                content_type='text/xml; charset=utf-8',
                status=500
            )
    
    def handle_device_discovery(self, parsed_data, client_ip, request):
        """Handle automatic device discovery"""
        from .models import DeviceInform, DeviceParameter
        
        device_info = parsed_data.get('device_info', {})
        parameters = parsed_data.get('parameters', {})
        
        # Extract key information
        oui = device_info.get('OUI', '')
        serial_number = device_info.get('SerialNumber', '')
        product_class = device_info.get('ProductClass', '')
        manufacturer = device_info.get('Manufacturer', '')
        
        if not serial_number:
            logger.warning("No serial number in device info")
            return
            
        device_id = f"{oui}-{serial_number}"
        
        # Create or update device record
        device_inform, created = DeviceInform.objects.get_or_create(
            oui=oui,
            serial_number=serial_number,
            defaults={
                'device_id': device_id,
                'product_class': product_class,
                'manufacturer': manufacturer,
                'model_name': device_info.get('ModelName', ''),
                'software_version': device_info.get('SoftwareVersion', ''),
                'hardware_version': device_info.get('HardwareVersion', ''),
                'ip_address': client_ip,
                'is_online': True,
                'auto_discovered': True
            }
        )
        
        if not created:
            # Update existing device
            device_inform.ip_address = client_ip
            device_inform.is_online = True
            device_inform.save()
        
        # Auto-create ONU record if new device
        if created:
            device_inform.create_onu_record()
            logger.info(f"Auto-discovered new device: {device_id}")
        
        # Store/update parameters
        for param_name, param_value in parameters.items():
            DeviceParameter.objects.update_or_create(
                device_inform=device_inform,
                parameter_name=param_name,
                defaults={
                    'parameter_value': param_value,
                    'value_type': self.determine_value_type(param_value)
                }
            )
    
    def handle_other_soap_messages(self, soap_data, request):
        """Handle non-Inform SOAP messages"""
        # For now, return empty response
        # This can be expanded to handle GetParameterValuesResponse, etc.
        
        return HttpResponse(
            '<?xml version="1.0" encoding="UTF-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"><soap:Body></soap:Body></soap:Envelope>'.encode('utf-8'),
            content_type='text/xml; charset=utf-8',
            status=200
        )
    
    def create_soap_fault(self, fault_code, fault_string):
        """Create SOAP Fault response"""
        return f'''<?xml version="1.0" encoding="UTF-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
    <soap:Body>
        <soap:Fault>
            <faultcode>{fault_code}</faultcode>
            <faultstring>{fault_string}</faultstring>
        </soap:Fault>
    </soap:Body>
</soap:Envelope>'''
    
    def get_client_ip(self, request):
        """Get client IP address"""
        x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
        if x_forwarded_for:
            ip = x_forwarded_for.split(',')[0]
        else:
            ip = request.META.get('REMOTE_ADDR')
        return ip
    
    def determine_value_type(self, value):
        """Determine parameter value type"""
        if isinstance(value, bool):
            return 'boolean'
        elif isinstance(value, int):
            return 'int'
        elif isinstance(value, float):
            return 'float'
        else:
            return 'string' 