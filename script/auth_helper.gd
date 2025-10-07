extends Node

signal token_received(code: String) # emits the authorization code

var server: TCPServer = TCPServer.new()
var port: int = 8765
var is_listening: bool = false

# Use the same client ID that you registered for Web in Google Cloud / Firebase
const CLIENT_ID: String = "1055956713490-tr6mh6pd994opb1hm2rmtmar1eilb3rm.apps.googleusercontent.com"

func start_google_login() -> void:
	var err = server.listen(port)
	if err != OK:
		push_error("❌ Failed to start TCP server: %s" % err)
		return

	print("✅ Listening on http://127.0.0.1:%d" % port)
	set_process(true)
	is_listening = true

	# Build Google OAuth URL using response_type=code so redirect contains ?code=...
	var redirect_uri: String = "http://127.0.0.1:%d" % port
	var scope: String = "openid%20email%20profile"

	# Use RNG instead of OS.get_unix_time() to avoid missing API on some Godot versions
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var state: String = str(rng.randi())

	var oauth_url: String = (
		"https://accounts.google.com/o/oauth2/v2/auth?"
		+ "client_id=%s"
		+ "&redirect_uri=%s"
		+ "&response_type=code"
		+ "&scope=%s"
		+ "&access_type=offline"
		+ "&prompt=select_account"
		+ "&state=%s"
	) % [CLIENT_ID, redirect_uri.uri_encode(), scope, state]

	OS.shell_open(oauth_url)


func _process(_delta: float) -> void:
	if not is_listening:
		return

	if server.is_connection_available():
		var peer = server.take_connection()
		if peer:
			# read available bytes (if any)
			var bytes_avail := peer.get_available_bytes()
			if bytes_avail <= 0:
				# nothing to read yet
				return
			var raw: String = peer.get_utf8_string(bytes_avail)
			print("🌐 Raw redirect data:\n", raw)

			# parse first request line to extract path + query
			# Example request start: "GET /?code=...&scope=... HTTP/1.1"
			var first_line: String = raw.split("\r\n")[0]
			var code: String = ""
			if first_line.begins_with("GET "):
				var parts := first_line.split(" ")
				if parts.size() >= 2:
					var path_and_q: String = parts[1] # e.g. "/?code=...&state=..."
					if "?" in path_and_q:
						var q: String = path_and_q.split("?", false, 1)[1]
						for pair in q.split("&"):
							if pair.begins_with("code="):
								# decode the code param
								code = pair.split("=", false, 1)[1].uri_decode()
								break

			# build a valid HTTP response
			var html: String = "<html><body><h2>✅ Successful! You can close this window.</h2></body></html>"
			var body_buf: PackedByteArray = html.to_utf8_buffer()
			var header: String = "HTTP/1.1 200 OK\r\n"
			header += "Content-Type: text/html; charset=UTF-8\r\n"
			header += "Content-Length: %d\r\n" % body_buf.size()
			header += "Connection: close\r\n\r\n"

			# send header + body
			peer.put_data(header.to_utf8_buffer())
			peer.put_data(body_buf)

			peer.disconnect_from_host()

			# stop server
			server.stop()
			is_listening = false
			set_process(false)

			if code != "":
				print("✅ Got auth code:", code)
				emit_signal("token_received", code)
			else:
				push_error("⚠️ No code found in redirect.")
