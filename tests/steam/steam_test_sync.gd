class_name SteamTestSync
extends Node
## The lockstep between the two machines of a Steam test run, and the keeper of the world they share.
##
## Each side marks the steps it reaches and waits for the other side's marks, so both run the same scenario in the
## same order and hand off at the same points. [SteamTest] adds one of these under /root as "SteamTestSync" on both
## machines, so the RPCs find the same path either side. A mark is sent with call_remote and recorded locally by
## hand rather than through one call_local RPC, because a side's own mark must never satisfy its own wait.
##
## The world lives here too, rather than under a test, because GUT frees each test script once it has run and the
## Steam session has to outlive all of them; the first scenario's before_all adds it and the last one's after_all
## takes it down.

signal marked(step: String) ## The other side reached [param step].

const RESEND_MS: int = 1000 ## How often a waiting side repeats its own marks. Marks travel unreliably, so a lost one costs this long and no more; repeating what this side has already said is what makes that safe.
const RESEND_LAST: int = 4 ## How many of the newest marks a waiting side repeats; the rest have long since landed.

var world: Node3D ## The world of the run; null until the session is up and again once it is torn down.
var other_peer_gone: bool = false ## The other side's process has left the session; every wait ends at once.

var _steam: Object = Engine.get_singleton("Steam") if Engine.has_singleton("Steam") else null
var _theirs: Dictionary[String, Variant] = {} ## Steps the other side has marked, with the values it sent.
var _mine: Dictionary[String, Variant] = {} ## Steps this side has marked.


func _ready() -> void:
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)


## GodotSteam's embedded callbacks run on frame_post_draw, which a headless Godot never emits since it draws no
## frame, so the lobby callbacks the session waits on would never arrive; pumping them here keeps the run headless.
func _process(_delta: float) -> void:
	if _steam:
		_steam.call("run_callbacks")


## Records that this side reached [param step], carrying [param value] to the other side (anything an RPC can carry).
func mark(step: String, value: Variant = null) -> void:
	_mine[step] = value
	print("[sync %d] send %s" % [Time.get_ticks_msec(), step])
	_mark_sure.rpc(step, value)


## Whether the other side has marked [param step].
func reached(step: String) -> bool:
	return _theirs.has(step)


## Whether this side has marked [param step].
func marked_myself(step: String) -> bool:
	return _mine.has(step)


## Waits until the other side has marked [param step] and returns the value it sent; null after [param timeout]
## seconds (two minutes by default: a Steam relay stall of a minute between the machines has been seen, and a
## wait that outlives it keeps the rest of the run in step)
## seconds without it, or at once when the other side has gone, which the caller tells apart with [method reached].
func await_step(step: String, timeout: float = 120.0) -> Variant:
	var deadline: int = Time.get_ticks_msec() + int(timeout * 1000.0)
	var resend_at: int = Time.get_ticks_msec() + RESEND_MS
	while not _theirs.has(step):
		if other_peer_gone:
			push_error("SteamTestSync: the other side left the session before '%s'" % step)
			return null
		if Time.get_ticks_msec() >= deadline:
			push_error("SteamTestSync: the other side never reached '%s' within %.0f s" % [step, timeout])
			return null
		if Time.get_ticks_msec() >= resend_at:
			# A mark is a fact, not an event, so saying it again costs nothing and covers the one that went astray
			# Only the newest few: a burst of a hundred datagrams loses its tail, which is exactly the mark that matters
			var recent: Array = _mine.keys().slice(-RESEND_LAST)
			for mine: String in recent:
				_mark.rpc(mine, _mine[mine])
			resend_at = Time.get_ticks_msec() + RESEND_MS
		await get_tree().process_frame
	return _theirs[step]


## Marks [param step] and waits for the other side's mark of it; returns the value the other side sent.
func barrier(step: String, value: Variant = null, timeout: float = 120.0) -> Variant:
	mark(step, value)
	return await await_step(step, timeout)


## A mark goes out once on the reliable stream, which delivers unless the relay stalls, and then again among the
## newest few every second as unreliable datagrams, which get through a stall the moment the link is back.
## Duplicates are harmless: a mark is a fact.
@rpc("any_peer", "call_remote", "reliable")
func _mark_sure(step: String, value: Variant = null) -> void:
	_mark(step, value)


@rpc("any_peer", "call_remote", "unreliable")
func _mark(step: String, value: Variant = null) -> void:
	if not _theirs.has(step):
		print("[sync %d] got %s from %d" % [Time.get_ticks_msec(), step, multiplayer.get_remote_sender_id()])
	_theirs[step] = value
	marked.emit(step)


## The other side's process ended (its run finished, or it was killed): nothing more will ever be marked, so every
## wait gives up now instead of sitting out its timeout, and this side's run ends with its own report written.
func _on_peer_disconnected(peer_id: int) -> void:
	print("[steam_test] peer %d disconnected" % peer_id)
	other_peer_gone = true
