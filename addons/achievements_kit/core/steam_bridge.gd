class_name AKSteamBridge
extends AKPlatformBridge
## Sends unlocks and stats to Steam through the GodotSteam addon, when it is present.
## Without GodotSteam (or outside Steam) it does nothing: no hard dependency.
## Create the achievements and stats with the same API names in Steamworks first.


func is_available() -> bool:
	return Engine.has_singleton("Steam")


func unlock(platform_name: String) -> void:
	if is_available():
		Engine.get_singleton("Steam").call("setAchievement", platform_name)


func set_stat(stat: StringName, value: int) -> void:
	if is_available():
		Engine.get_singleton("Steam").call("setStatInt", String(stat), value)


func store() -> void:
	if is_available():
		Engine.get_singleton("Steam").call("storeStats")
