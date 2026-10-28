class_name AKPlatformBridge
extends RefCounted
## Mirrors unlocks to a platform (Steam, consoles, a server). Extend it, or use
## [AKSteamBridge]. Every call is optional: the kit works without any bridge.


## Called once for each unlock, with [method AKAchievement.get_platform_name].
func unlock(_platform_name: String) -> void:
	pass


## Called when a stat changes (platforms that track stats themselves).
func set_stat(_stat: StringName, _value: int) -> void:
	pass


## Called after a batch of changes, to persist them on the platform.
func store() -> void:
	pass
