class_name RPGLog
extends RefCounted
## The game's log channel (Unreal's LogRPG). Lines start with "[RPG]" and the machine's role, so the logs of a
## host and its clients can be told apart. Verbose lines (every ability release and hit on the server) are shown
## with the --log-verbose command line argument.

static var verbose_enabled := false
## Set by Session: "host", "client 12345678", "offline".
static var role := "offline"


static func info(message: String) -> void:
	print("[RPG][%s] %s" % [role, message])


static func verbose(message: String) -> void:
	if verbose_enabled:
		print("[RPG][%s] %s" % [role, message])


static func warn(message: String) -> void:
	push_warning("[RPG][%s] %s" % [role, message])
	print("[RPG][%s] WARNING: %s" % [role, message])
