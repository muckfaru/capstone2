extends Node

"""
NetworkHelper.gd
Utility class for network operations: public IP detection, port checking, etc.
Used for Option A: Pure Direct P2P Architecture
"""

signal public_ip_detected(ip: String)
# signal public_ip_failed(error: String)  # Reserved for future error handling
signal port_check_complete(is_open: bool)
signal upnp_completed(success: bool, message: String)

const PUBLIC_IP_API := "https://api.ipify.org?format=json"
const PUBLIC_IP_API_FALLBACK := "https://api64.ipify.org?format=json"  # IPv4 fallback
const PUBLIC_IP_API_FALLBACK2 := "https://icanhazip.com"  # Second fallback
const PORT_CHECK_API := "https://portchecker.io/api/check"
const DEFAULT_PORT := 7777

var _public_ip: String = ""
var _local_ip: String = ""
var _upnp: UPNP = null
var _upnp_mapped: bool = false

## Get public IP address (WAN IP visible to internet)
func detect_public_ip() -> void:
	print("[NetworkHelper] Detecting public IP...")
	_try_detect_public_ip(PUBLIC_IP_API, 0)


func _try_detect_public_ip(api_url: String, attempt: int) -> void:
	var http := HTTPRequest.new()
	add_child(http)
	
	http.request_completed.connect(func(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
		http.queue_free()
		
		if response_code != 200:
			print("[NetworkHelper] Failed to detect public IP (attempt %d): HTTP %d" % [attempt + 1, response_code])
			
			# Try fallbacks
			if attempt == 0:
				print("[NetworkHelper] Trying fallback API...")
				_try_detect_public_ip(PUBLIC_IP_API_FALLBACK, 1)
			elif attempt == 1:
				print("[NetworkHelper] Trying second fallback API...")
				_try_detect_public_ip(PUBLIC_IP_API_FALLBACK2, 2)
			else:
				# All APIs failed, use local IP as fallback
				print("[NetworkHelper] ⚠️ All IP detection APIs failed")
				print("[NetworkHelper] Using local IP as fallback for LAN-only play")
				_public_ip = get_local_ip()
				print("[NetworkHelper] Fallback IP: %s (LAN only)" % _public_ip)
				public_ip_detected.emit(_public_ip)
			return
		
		var json_str := body.get_string_from_utf8().strip_edges()
		
		# Handle different response formats
		if api_url.contains("icanhazip"):
			# Plain text response
			_public_ip = json_str
		else:
			# JSON response
			var parsed = JSON.parse_string(json_str)
			if parsed == null or not parsed.has("ip"):
				print("[NetworkHelper] Invalid response format from %s" % api_url)
				if attempt < 2:
					_try_detect_public_ip(PUBLIC_IP_API_FALLBACK if attempt == 0 else PUBLIC_IP_API_FALLBACK2, attempt + 1)
				else:
					_public_ip = get_local_ip()
					public_ip_detected.emit(_public_ip)
				return
			_public_ip = str(parsed["ip"])
		
		print("[NetworkHelper] ✅ Public IP detected: %s" % _public_ip)
		public_ip_detected.emit(_public_ip)
	)
	
	var error := http.request(api_url)
	if error != OK:
		http.queue_free()
		print("[NetworkHelper] Failed to send request to %s: %d" % [api_url, error])
		if attempt < 2:
			_try_detect_public_ip(PUBLIC_IP_API_FALLBACK if attempt == 0 else PUBLIC_IP_API_FALLBACK2, attempt + 1)
		else:
			_public_ip = get_local_ip()
			public_ip_detected.emit(_public_ip)


## Get local IP address (LAN IP, e.g., 192.168.x.x)
func get_local_ip() -> String:
	if _local_ip != "":
		return _local_ip
	
	# Get all network interfaces
	var interfaces = IP.get_local_interfaces()
	
	for iface in interfaces:
		if not iface.has("addresses"):
			continue
		
		for address in iface["addresses"]:
			var ip = str(address)
			
			# Skip loopback and IPv6
			if ip.begins_with("127.") or ip.begins_with("::") or ip.begins_with("fe80:"):
				continue
			
			# Prefer private IP ranges (192.168.x.x, 10.x.x.x, 172.16-31.x.x)
			if ip.begins_with("192.168.") or ip.begins_with("10."):
				_local_ip = ip
				print("[NetworkHelper] Local IP: %s" % _local_ip)
				return _local_ip
			
			# Also accept 172.16-31.x.x range
			if ip.begins_with("172."):
				var parts = ip.split(".")
				if parts.size() >= 2:
					var second_octet = int(parts[1])
					if second_octet >= 16 and second_octet <= 31:
						_local_ip = ip
						print("[NetworkHelper] Local IP: %s" % _local_ip)
						return _local_ip
	
	# Fallback: return first non-loopback IPv4 address
	for iface in interfaces:
		if not iface.has("addresses"):
			continue
		for address in iface["addresses"]:
			var ip = str(address)
			if not ip.begins_with("127.") and not ip.begins_with("::") and not ip.begins_with("fe80:"):
				if ":" not in ip:  # IPv4 only
					_local_ip = ip
					print("[NetworkHelper] Local IP (fallback): %s" % _local_ip)
					return _local_ip
	
	print("[NetworkHelper] ⚠️ Could not detect local IP")
	return ""


## Check if a port is open/accessible from internet
func check_port_accessible(port: int) -> void:
	print("[NetworkHelper] Checking if port %d is accessible..." % port)
	
	# Note: portchecker.io API requires public IP
	# For now, just emit success (actual check would need backend support)
	# You can implement this by pinging your own server from public IP
	
	await get_tree().create_timer(1.0).timeout
	
	print("[NetworkHelper] ⚠️ Port checking not fully implemented")
	print("[NetworkHelper] Assuming port is open (requires manual verification)")
	port_check_complete.emit(true)


## Get cached public IP (call detect_public_ip() first)
func get_public_ip() -> String:
	return _public_ip


## Determine if we're on same network as another IP
func is_same_network(other_ip: String) -> bool:
	var local = get_local_ip()
	if local.is_empty() or other_ip.is_empty():
		return false
	
	# Simple check: same first 3 octets (e.g., 192.168.1.x)
	var local_parts = local.split(".")
	var other_parts = other_ip.split(".")
	
	if local_parts.size() >= 3 and other_parts.size() >= 3:
		return (local_parts[0] == other_parts[0] and 
				local_parts[1] == other_parts[1] and 
				local_parts[2] == other_parts[2])
	
	return false


## Get connection type (LAN or WAN)
func get_connection_type(target_ip: String) -> String:
	if is_same_network(target_ip):
		return "LAN"
	else:
		return "WAN"


## Format IP for display (hide middle octets for privacy)
func format_ip_for_display(ip: String) -> String:
	var parts = ip.split(".")
	if parts.size() == 4:
		return "%s.***.***.%s" % [parts[0], parts[3]]
	return ip


# =============================================================================
# UPnP PORT FORWARDING (Automatic Router Configuration)
# =============================================================================

## Setup UPnP port forwarding (async, non-blocking)
func setup_upnp_port_forwarding(port: int = DEFAULT_PORT) -> void:
	"""
	Attempt to automatically open a port on the router using UPnP.
	This allows hosting without manual port forwarding.
	
	Emits: upnp_completed(success: bool, message: String)
	"""
	print("[NetworkHelper] Starting UPnP port forwarding setup for port %d..." % port)
	
	_upnp = UPNP.new()
	
	# Discover UPnP devices (routers) - this is blocking but usually fast (<2s)
	var discover_result = _upnp.discover(2000, 2, "InternetGatewayDevice")
	
	if discover_result != UPNP.UPNP_RESULT_SUCCESS:
		var error_msg = "UPnP discovery failed: %s" % _get_upnp_error_string(discover_result)
		print("[NetworkHelper] ⚠️ %s" % error_msg)
		upnp_completed.emit(false, error_msg)
		return
	
	var gateway = _upnp.get_gateway()
	if gateway == null or not gateway.is_valid_gateway():
		var error_msg = "No valid UPnP gateway found (router may not support UPnP)"
		print("[NetworkHelper] ⚠️ %s" % error_msg)
		upnp_completed.emit(false, error_msg)
		return
	
	print("[NetworkHelper] UPnP gateway found: %s" % gateway.query_external_address())
	
	# Add port mapping (external port → internal port)
	# Note: UPnP handles internal IP automatically
	var add_result = _upnp.add_port_mapping(
		port,           # External port (what internet sees)
		port,           # Internal port (your PC's port)
		"Code Breaker", # Description
		"TCP"           # Protocol
	)
	
	if add_result != UPNP.UPNP_RESULT_SUCCESS:
		var error_msg = "Failed to add port mapping: %s" % _get_upnp_error_string(add_result)
		print("[NetworkHelper] ⚠️ %s" % error_msg)
		upnp_completed.emit(false, error_msg)
		return
	
	_upnp_mapped = true
	var success_msg = "Port %d opened successfully via UPnP" % port
	print("[NetworkHelper] ✅ %s" % success_msg)
	upnp_completed.emit(true, success_msg)


## Remove UPnP port mapping (cleanup)
func cleanup_upnp_port_forwarding(port: int = DEFAULT_PORT) -> void:
	"""Remove the port mapping when closing the room"""
	if not _upnp_mapped or _upnp == null:
		return
	
	print("[NetworkHelper] Cleaning up UPnP port mapping for port %d..." % port)
	
	var delete_result = _upnp.delete_port_mapping(port, "TCP")
	
	if delete_result == UPNP.UPNP_RESULT_SUCCESS:
		print("[NetworkHelper] ✅ UPnP port mapping removed")
	else:
		print("[NetworkHelper] ⚠️ Failed to remove UPnP mapping: %s" % _get_upnp_error_string(delete_result))
	
	_upnp_mapped = false


## Get human-readable UPnP error message
func _get_upnp_error_string(error_code: int) -> String:
	match error_code:
		UPNP.UPNP_RESULT_SUCCESS:
			return "Success"
		UPNP.UPNP_RESULT_NOT_AUTHORIZED:
			return "Not authorized (check router settings)"
		UPNP.UPNP_RESULT_PORT_MAPPING_NOT_FOUND:
			return "Port mapping not found"
		UPNP.UPNP_RESULT_INCONSISTENT_PARAMETERS:
			return "Inconsistent parameters"
		UPNP.UPNP_RESULT_NO_SUCH_ENTRY_IN_ARRAY:
			return "No such entry in array"
		UPNP.UPNP_RESULT_ACTION_FAILED:
			return "Action failed"
		UPNP.UPNP_RESULT_SRC_IP_WILDCARD_NOT_PERMITTED:
			return "Source IP wildcard not permitted"
		UPNP.UPNP_RESULT_EXT_PORT_WILDCARD_NOT_PERMITTED:
			return "External port wildcard not permitted"
		UPNP.UPNP_RESULT_INT_PORT_WILDCARD_NOT_PERMITTED:
			return "Internal port wildcard not permitted"
		UPNP.UPNP_RESULT_REMOTE_HOST_MUST_BE_WILDCARD:
			return "Remote host must be wildcard"
		UPNP.UPNP_RESULT_EXT_PORT_MUST_BE_WILDCARD:
			return "External port must be wildcard"
		UPNP.UPNP_RESULT_NO_PORT_MAPS_AVAILABLE:
			return "No port maps available"
		UPNP.UPNP_RESULT_CONFLICT_WITH_OTHER_MECHANISM:
			return "Conflict with other mechanism"
		UPNP.UPNP_RESULT_CONFLICT_WITH_OTHER_MAPPING:
			return "Conflict with other mapping (port already in use)"
		UPNP.UPNP_RESULT_SAME_PORT_VALUES_REQUIRED:
			return "Same port values required"
		UPNP.UPNP_RESULT_ONLY_PERMANENT_LEASE_SUPPORTED:
			return "Only permanent lease supported"
		UPNP.UPNP_RESULT_INVALID_GATEWAY:
			return "Invalid gateway"
		UPNP.UPNP_RESULT_INVALID_PORT:
			return "Invalid port"
		UPNP.UPNP_RESULT_INVALID_PROTOCOL:
			return "Invalid protocol"
		UPNP.UPNP_RESULT_INVALID_DURATION:
			return "Invalid duration"
		UPNP.UPNP_RESULT_INVALID_ARGS:
			return "Invalid arguments"
		UPNP.UPNP_RESULT_INVALID_RESPONSE:
			return "Invalid response from router"
		UPNP.UPNP_RESULT_INVALID_PARAM:
			return "Invalid parameter"
		UPNP.UPNP_RESULT_HTTP_ERROR:
			return "HTTP error"
		UPNP.UPNP_RESULT_SOCKET_ERROR:
			return "Socket error"
		UPNP.UPNP_RESULT_MEM_ALLOC_ERROR:
			return "Memory allocation error"
		UPNP.UPNP_RESULT_NO_GATEWAY:
			return "No gateway found"
		UPNP.UPNP_RESULT_NO_DEVICES:
			return "No UPnP devices found"
		UPNP.UPNP_RESULT_UNKNOWN_ERROR:
			return "Unknown error"
		_:
			return "Error code: %d" % error_code


## Check if UPnP is currently active
func is_upnp_active() -> bool:
	return _upnp_mapped and _upnp != null


## Get UPnP gateway info (for debugging)
func get_upnp_info() -> Dictionary:
	if _upnp == null:
		return {}
	
	var gateway = _upnp.get_gateway()
	if gateway == null:
		return {}
	
	return {
		"valid": gateway.is_valid_gateway(),
		"external_ip": gateway.query_external_address(),
		"service_type": gateway.get_service_type(),
		"mapped": _upnp_mapped
	}
