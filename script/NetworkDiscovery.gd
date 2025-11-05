extends Node

## NetworkDiscovery - Exchange host IP via Firebase RTDB for P2P connection

const RTDB_BASE := "https://capstone-823dc-default-rtdb.firebaseio.com"

signal host_ip_received(ip: String)
signal discovery_failed(error: String)

func publish_host_ip(room_id: String, ip: String, port: int, id_token: String) -> void:
	"""Host publishes their IP to RTDB for client to discover"""
	var network_info := {
		"host_ip": ip,
		"port": port,
		"timestamp": int(Time.get_unix_time_from_system())
	}
	
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, _b):
		http.queue_free()
		if code == 200:
			print("[NetworkDiscovery] Host IP published: %s:%d" % [ip, port])
		else:
			push_error("[NetworkDiscovery] Failed to publish IP: HTTP %d" % code)
			emit_signal("discovery_failed", "Failed to publish IP")
	)
	
	var url := RTDB_BASE + "/codebreaker_rooms/" + room_id + "/network_info.json?auth=" + id_token
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_PUT, JSON.stringify(network_info))

func get_host_ip(room_id: String) -> void:
	"""Client fetches host IP from RTDB"""
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, body: PackedByteArray):
		http.queue_free()
		if code != 200:
			push_error("[NetworkDiscovery] Failed to fetch host IP: HTTP %d" % code)
			emit_signal("discovery_failed", "Failed to fetch host IP")
			return
		
		var data = JSON.parse_string(body.get_string_from_utf8())
		if typeof(data) != TYPE_DICTIONARY:
			emit_signal("discovery_failed", "Invalid network info")
			return
		
		var host_ip = str(data.get("host_ip", ""))
		if host_ip.is_empty():
			emit_signal("discovery_failed", "No host IP found")
			return
		
		print("[NetworkDiscovery] Host IP received: %s" % host_ip)
		emit_signal("host_ip_received", host_ip)
	)
	
	var url := RTDB_BASE + "/codebreaker_rooms/" + room_id + "/network_info.json"
	http.request(url, [], HTTPClient.METHOD_GET)

func get_local_network_ip() -> String:
	"""Get this machine's local network IP (192.168.x.x or 10.x.x.x)"""
	var addresses = IP.get_local_addresses()
	for address in addresses:
		# Prefer private network ranges
		if address.begins_with("192.168.") or address.begins_with("10.") or address.begins_with("172."):
			return address
	return "127.0.0.1"

func get_public_ip() -> void:
	"""Fetch public IP from external service (for internet play)"""
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, body: PackedByteArray):
		http.queue_free()
		if code == 200:
			var ip = body.get_string_from_utf8().strip_edges()
			print("[NetworkDiscovery] Public IP: %s" % ip)
			emit_signal("host_ip_received", ip)
		else:
			emit_signal("discovery_failed", "Failed to get public IP")
	)
	
	# Use multiple services as fallback
	var services = [
		"https://api.ipify.org",
		"https://icanhazip.com",
		"https://ifconfig.me/ip"
	]
	http.request(services[0], [], HTTPClient.METHOD_GET)
