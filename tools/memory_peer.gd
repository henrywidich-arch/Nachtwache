extends MultiplayerPeerExtension
## Test-only packet transport. Godot still serializes and checks real RPCs, but all
## packets stay in memory so the session checks also run without network permission.

var id := 1
var other: MultiplayerPeerExtension
var inbox: Array = []
var mode := MultiplayerPeer.TRANSFER_MODE_RELIABLE
var channel := 0
var status := MultiplayerPeer.CONNECTION_CONNECTING
var announced := false

func _init(peer_id: int = 1) -> void:
	id = peer_id

func _get_unique_id() -> int:
	return id

func _is_server() -> bool:
	return id == 1

func _is_server_relay_supported() -> bool:
	return false

func _get_connection_status() -> MultiplayerPeer.ConnectionStatus:
	return status

func _get_available_packet_count() -> int:
	return inbox.size()

func _get_max_packet_size() -> int:
	return 1048576

func _get_packet_peer() -> int:
	return 2 if id == 1 else 1

func _get_packet_channel() -> int:
	return 0

func _get_packet_mode() -> MultiplayerPeer.TransferMode:
	return MultiplayerPeer.TRANSFER_MODE_RELIABLE

func _get_packet_script() -> PackedByteArray:
	return inbox.pop_front() if not inbox.is_empty() else PackedByteArray()

func _put_packet_script(buffer: PackedByteArray) -> Error:
	if other == null:
		return ERR_UNCONFIGURED
	other.inbox.append(buffer.duplicate())
	return OK

func _poll() -> void:
	if not announced and other != null:
		announced = true
		status = MultiplayerPeer.CONNECTION_CONNECTED
		peer_connected.emit(2 if id == 1 else 1)

func _get_transfer_channel() -> int:
	return channel

func _set_transfer_channel(value: int) -> void:
	channel = value

func _get_transfer_mode() -> MultiplayerPeer.TransferMode:
	return mode

func _set_transfer_mode(value: MultiplayerPeer.TransferMode) -> void:
	mode = value

func _set_target_peer(_peer: int) -> void:
	pass

func _close() -> void:
	status = MultiplayerPeer.CONNECTION_DISCONNECTED
	other = null
	inbox.clear()

func _disconnect_peer(_peer: int, _force: bool) -> void:
	_close()
