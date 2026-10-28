class_name AKAchievements
extends Node
## The player's stats and achievements.
##
## Count anything with [method add_stat] (or follow items picked up with
## [method watch_items]); achievements unlock by themselves when their stat reaches its
## goal. Rewards are claimed with [method claim], in one [IKTransaction]: a full bag
## never loses a reward, the player simply claims it later.
##
## Without Steam (itch.io, web, DRM-free builds), turn on [member auto_save]: progress is
## written to [member save_path] after every unlock, progress and claim, and read back
## when the node is ready. Progress toasts ("50/100") come from [member progress_percents]
## or each achievement's [member AKAchievement.progress_milestones].
## [codeblock]
## achievements.add_stat(&"wolves_killed")
## achievements.unlocked.connect(func(a): toast.show_achievement(a))
## [/codeblock]

signal unlocked(achievement: AKAchievement)
signal stat_changed(stat: StringName, value: int)
signal reward_claimed(achievement: AKAchievement)
signal changed
## A stat crossed a progress milestone of a locked, non-secret achievement ("50/100").
signal progress_reached(achievement: AKAchievement, value: int, goal: int)
## [method save_local] wrote the file ([param error] = OK) or failed.
signal saved(error: Error)

const DATA_VERSION := 1
## Stats made by [method watch_items]: "item:oak_log" = oak logs gained so far.
const ITEM_STAT_PREFIX := "item:"

@export var list: AKAchievementList
## Item definitions, for icons and reward names. Defaults to the watched container's.
@export var database: IKItemDatabase
## Progress notifications at these percents of every goal: [25, 50, 75]. Empty = none
## (unlock toasts only). An achievement's own [member AKAchievement.progress_milestones] win.
@export var progress_percents: PackedInt32Array = []
@export_group("Local save")
## Saves to [member save_path] after every change and loads it when the node is ready.
## Set [member list] before adding the node. Off by default (you save with [method to_data]).
@export var auto_save := false
## Any writable path: "user://achievements.save" (the default), "user://slot1/achievements.json"...
@export var save_path := "user://achievements.save"
## Optional: mirror unlocks to Steam or another platform.
var bridge: AKPlatformBridge

var _stats: Dictionary = {}  # stat -> int
var _unlocked: Dictionary = {}  # achievement id -> unix time
var _claimed: Dictionary = {}  # achievement id -> true
var _watched: Array[IKContainer] = []
var _save_queued := false
var _loading := false


func _ready() -> void:
	if list == null:
		list = AKAchievementList.new()
	changed.connect(_on_changed)
	if auto_save:
		load_local()


func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT] and _save_queued:
		save_local()


func _exit_tree() -> void:
	if _save_queued:
		save_local()
	for container in _watched:
		if container.item_added.is_connected(_on_item_added):
			container.item_added.disconnect(_on_item_added)
	_watched.clear()


# --- Stats -----------------------------------------------------------------------

func get_stat(stat: StringName) -> int:
	return _stats.get(stat, 0)


func add_stat(stat: StringName, amount: int = 1) -> void:
	if amount != 0:
		set_stat(stat, get_stat(stat) + amount)


## Sets a stat. With [param keep_highest], only raises it ("most gold ever held").
func set_stat(stat: StringName, value: int, keep_highest: bool = false) -> void:
	if keep_highest and value <= get_stat(stat):
		return
	var old := get_stat(stat)
	if value == old:
		return
	_stats[stat] = value
	stat_changed.emit(stat, value)
	if bridge != null:
		bridge.set_stat(stat, value)
	_check(stat)
	if value > old:
		_notify_progress(stat, old, value)
	changed.emit()


## Counts every item [param container] gains (pick-ups, crafts, purchases, rewards)
## in the stat "item:<id>": achievements like "Gather 100 oak logs".
func watch_items(container: IKContainer) -> void:
	if container == null or _watched.has(container):
		return
	_watched.append(container)
	if database == null:
		database = container.database
	container.item_added.connect(_on_item_added)


# --- Achievements ------------------------------------------------------------------

func is_unlocked(achievement_id: StringName) -> bool:
	return _unlocked.has(achievement_id)


## Unix time of the unlock, 0 if locked.
func get_unlock_time(achievement_id: StringName) -> int:
	return _unlocked.get(achievement_id, 0)


## Progress toward the goal, 0..goal.
func get_progress(achievement_id: StringName) -> int:
	var achievement := list.get_achievement(achievement_id)
	if achievement == null:
		return 0
	if is_unlocked(achievement_id):
		return achievement.goal
	return clampi(get_stat(achievement.stat), 0, achievement.goal) if not achievement.stat.is_empty() else 0


func get_points() -> int:
	var total := 0
	for achievement_id in _unlocked:
		var achievement := list.get_achievement(achievement_id)
		total += achievement.points if achievement != null else 0
	return total


func get_unlocked_count() -> int:
	return _unlocked.size()


## Unlocks by hand (story moments, secrets). False if unknown or already unlocked.
func unlock(achievement_id: StringName) -> bool:
	var achievement := list.get_achievement(achievement_id)
	if achievement == null or is_unlocked(achievement_id):
		return false
	_unlocked[achievement_id] = int(Time.get_unix_time_from_system())
	unlocked.emit(achievement)
	if bridge != null:
		bridge.unlock(achievement.get_platform_name())
		bridge.store()
	changed.emit()
	return true


func can_claim(achievement_id: StringName) -> bool:
	var achievement := list.get_achievement(achievement_id)
	return achievement != null and is_unlocked(achievement_id) and not _claimed.has(achievement_id) and not achievement.rewards.is_empty()


func is_claimed(achievement_id: StringName) -> bool:
	return _claimed.has(achievement_id)


## Gives the rewards of an unlocked achievement to [param bag], all or nothing.
func claim(achievement_id: StringName, bag: IKContainer) -> IKResult:
	if not can_claim(achievement_id) or bag == null:
		return IKResult.failure(IKResult.Code.INVALID_ARGUMENT, "%s: nothing to claim" % achievement_id)
	var achievement := list.get_achievement(achievement_id)
	var transaction := IKTransaction.new()
	for item_id in achievement.rewards:
		transaction.add(bag, item_id, achievement.rewards[item_id])
	var result := transaction.commit()
	if result.ok:
		_claimed[achievement_id] = true
		reward_claimed.emit(achievement)
		changed.emit()
	return result


# --- Saving ----------------------------------------------------------------------

## Writes [method to_data] to [member save_path] (JSON, through a temporary file so a crash
## never leaves half a save). Called for you with [member auto_save].
func save_local() -> Error:
	_save_queued = false
	DirAccess.make_dir_recursive_absolute(save_path.get_base_dir())
	var text := JSON.stringify(to_data(), "\t")
	var temp := save_path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		var open_error := FileAccess.get_open_error()
		saved.emit(open_error)
		return open_error
	file.store_string(text)
	file.close()
	var error := DirAccess.rename_absolute(temp, save_path)
	if error != OK:  # some platforms refuse to replace a file: write it directly
		file = FileAccess.open(save_path, FileAccess.WRITE)
		error = FileAccess.get_open_error() if file == null else OK
		if file != null:
			file.store_string(text)
			file.close()
		DirAccess.remove_absolute(temp)
	saved.emit(error)
	return error


## Reads [member save_path] back. False when there is no file yet or it is not a save.
func load_local() -> bool:
	if not FileAccess.file_exists(save_path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Achievements Kit: %s is not an achievements save, ignored." % save_path)
		return false
	_loading = true
	var ok := load_data(parsed)
	_loading = false
	return ok


## Deletes the local save (a "reset progress" button). Stats in memory are kept.
func delete_local() -> void:
	_save_queued = false
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)


func to_data() -> Dictionary:
	var stats := {}
	for stat in _stats:
		stats[String(stat)] = _stats[stat]
	var unlocked_ids := {}
	for achievement_id in _unlocked:
		unlocked_ids[String(achievement_id)] = _unlocked[achievement_id]
	var claimed := []
	for achievement_id in _claimed:
		claimed.append(String(achievement_id))
	return {"version": DATA_VERSION, "stats": stats, "unlocked": unlocked_ids, "claimed": claimed}


## Restores [method to_data], then unlocks what the stats already reach (achievements
## added in an update count past progress). No [signal unlocked] for restored unlocks.
func load_data(data: Dictionary) -> bool:
	if typeof(data.get("stats")) != TYPE_DICTIONARY or typeof(data.get("unlocked")) != TYPE_DICTIONARY:
		return false
	_stats.clear()
	for stat: Variant in data.stats:
		_stats[StringName(str(stat))] = int(data.stats[stat])
	_unlocked.clear()
	for raw: Variant in data.unlocked:
		if list.get_achievement(StringName(str(raw))) != null:
			_unlocked[StringName(str(raw))] = int(data.unlocked[raw])
	_claimed.clear()
	for raw: Variant in data.get("claimed", []):
		if _unlocked.has(StringName(str(raw))):
			_claimed[StringName(str(raw))] = true
	for stat in _stats:
		_check(stat)
	changed.emit()
	return true


func _check(stat: StringName) -> void:
	for achievement in list.achievements:
		if achievement != null and achievement.stat == stat and not is_unlocked(achievement.id) and get_stat(stat) >= achievement.goal:
			unlock(achievement.id)


func _notify_progress(stat: StringName, old: int, value: int) -> void:
	if _loading:
		return
	for achievement in list.achievements:
		if achievement == null or achievement.stat != stat or achievement.secret or is_unlocked(achievement.id):
			continue
		var reached := -1
		for milestone in achievement.get_milestones(progress_percents):
			if old < milestone and milestone <= value:
				reached = milestone  # several crossed at once: only the highest
		if reached > 0:
			progress_reached.emit(achievement, mini(value, achievement.goal), achievement.goal)


func _on_changed() -> void:
	if auto_save and not _loading and not _save_queued:
		_save_queued = true
		_flush_save.call_deferred()  # one write per frame, however many stats changed


func _flush_save() -> void:
	if _save_queued:
		save_local()


func _on_item_added(item_id: StringName, amount: int) -> void:
	add_stat(StringName(ITEM_STAT_PREFIX + String(item_id)), amount)
