class_name AKToast
extends PanelContainer
## "Achievement unlocked" pop-up: slides in, waits, slides out. Unlocks that arrive
## together are shown one after the other. Put it in your HUD (top-right corner by default).
## It also shows progress ("Wolf Hunter 50/100", with a bar) when
## [signal AKAchievements.progress_reached] fires.

@export var achievements: AKAchievements:
	set(value):
		if achievements != null:
			if achievements.unlocked.is_connected(show_achievement):
				achievements.unlocked.disconnect(show_achievement)
			if achievements.progress_reached.is_connected(show_progress):
				achievements.progress_reached.disconnect(show_progress)
		achievements = value
		if achievements != null:
			achievements.unlocked.connect(show_achievement)
			achievements.progress_reached.connect(show_progress)
## Seconds each toast stays on screen.
@export var duration: float = 3.0
## Shows progress toasts. Off = unlocks only.
@export var show_progress_toasts := true
## Progress toasts stay this long (they matter less than unlocks).
@export var progress_duration: float = 2.0

var _icon := TextureRect.new()
var _title := Label.new()
var _name := Label.new()
var _bar := ProgressBar.new()
var _queue: Array[Dictionary] = []  # {"achievement", "value", "goal"}; value < 0 = unlock
var _showing := false


func _init() -> void:
	visible = false
	mouse_filter = MOUSE_FILTER_IGNORE
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	margin.add_child(row)
	_icon.custom_minimum_size = Vector2(48, 48)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(_icon)
	var texts := VBoxContainer.new()
	row.add_child(texts)
	_title.add_theme_color_override(&"font_color", Color(1.0, 0.85, 0.35))
	texts.add_child(_title)
	_name.add_theme_font_size_override(&"font_size", 19)
	texts.add_child(_name)
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(160, 8)
	_bar.visible = false
	_bar.mouse_filter = MOUSE_FILTER_IGNORE
	texts.add_child(_bar)


func show_achievement(achievement: AKAchievement) -> void:
	_queue.append({"achievement": achievement, "value": -1, "goal": achievement.goal})
	if not _showing:
		_next()


## "Wolf Hunter 50/100". Ignored when [member show_progress_toasts] is off.
func show_progress(achievement: AKAchievement, value: int, goal: int) -> void:
	if not show_progress_toasts:
		return
	# A newer step of the same achievement replaces one still waiting.
	for entry in _queue:
		if entry.achievement == achievement and entry.value >= 0:
			entry.value = value
			return
	_queue.append({"achievement": achievement, "value": value, "goal": goal})
	if not _showing:
		_next()


## True while a toast is on screen or waiting.
func is_busy() -> bool:
	return _showing or not _queue.is_empty()


func _next() -> void:
	if _queue.is_empty() or not is_inside_tree():
		_showing = false
		visible = false
		return
	_showing = true
	var entry: Dictionary = _queue.pop_front()
	var achievement: AKAchievement = entry.achievement
	var progress: bool = entry.value >= 0
	_icon.texture = achievement.get_icon(achievements.database if achievements != null else null)
	_bar.visible = progress
	if progress:
		_title.text = AKText.t("Achievement progress")
		_name.text = "%s  %d/%d" % [achievement.get_title(), entry.value, entry.goal]
		_bar.max_value = maxi(1, entry.goal)
		_bar.value = entry.value
	else:
		_title.text = AKText.t("Achievement unlocked")
		_name.text = achievement.get_title()
	visible = true
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.25)
	tween.tween_interval(progress_duration if progress else duration)
	tween.tween_property(self, "modulate:a", 0.0, 0.35)
	tween.tween_callback(_next)
