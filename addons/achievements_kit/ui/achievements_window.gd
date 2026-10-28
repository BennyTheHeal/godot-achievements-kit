class_name AKAchievementsWindow
extends PanelContainer
## A ready-to-use achievements screen: total points and count, All / Unlocked / Locked
## filters, one row per achievement (icon, title, description, progress bar, points),
## secret ones shown as "???", and Claim buttons for rewards.
## Works with the mouse, the keyboard and a gamepad (focus moves between Claim buttons
## and rows). Set [member achievements] and [member bag].

signal claimed(achievement: AKAchievement)
signal refused(achievement: AKAchievement, text: String)
signal close_requested

enum Filter { ALL, UNLOCKED, LOCKED }

@export var achievements: AKAchievements:
	set(value):
		if achievements != null and achievements.changed.is_connected(_queue_refresh):
			achievements.changed.disconnect(_queue_refresh)
		achievements = value
		if achievements != null:
			achievements.changed.connect(_queue_refresh)
		_queue_refresh()
## Where claimed rewards go.
var bag: IKContainer

var filter: Filter = Filter.ALL
var _summary := Label.new()
var _filters: Array[Button] = []
var _rows := VBoxContainer.new()
var _status := Label.new()
var _refresh_queued := false


func _init() -> void:
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 8)
	margin.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = AKText.t("Achievements")
	title.add_theme_font_size_override(&"font_size", 22)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(title)
	_summary.add_theme_color_override(&"font_color", Color(1.0, 0.85, 0.35))
	header.add_child(_summary)
	var filter_row := HBoxContainer.new()
	column.add_child(filter_row)
	var group := ButtonGroup.new()
	for label in ["All", "Unlocked", "Locked"]:
		var button := Button.new()
		button.text = AKText.t(label)
		button.toggle_mode = true
		button.button_group = group
		button.focus_mode = FOCUS_NONE
		var index := _filters.size()
		button.pressed.connect(func() -> void: set_filter(index))
		filter_row.add_child(button)
		_filters.append(button)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	column.add_child(scroll)
	_rows.size_flags_horizontal = SIZE_EXPAND_FILL
	_rows.add_theme_constant_override(&"separation", 6)
	scroll.add_child(_rows)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)


func _ready() -> void:
	refresh()


func set_filter(value: int) -> void:
	filter = value as Filter
	refresh()


func refresh() -> void:
	_refresh_queued = false
	for i in _filters.size():
		_filters[i].button_pressed = i == filter
		_filters[i].modulate = Color.WHITE if i == filter else Color(1, 1, 1, 0.55)
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	if achievements == null or achievements.list == null:
		_summary.text = ""
		return
	var total := achievements.list.achievements.size()
	var possible := 0
	for achievement in achievements.list.achievements:
		possible += achievement.points if achievement != null else 0
	_summary.text = "%d / %d · %d / %d %s" % [achievements.get_unlocked_count(), total, achievements.get_points(), possible, AKText.t("points")]
	for achievement in achievements.list.achievements:
		if achievement == null:
			continue
		var unlocked := achievements.is_unlocked(achievement.id)
		if (filter == Filter.UNLOCKED and not unlocked) or (filter == Filter.LOCKED and unlocked):
			continue
		_rows.add_child(_row(achievement, unlocked))


func _row(achievement: AKAchievement, unlocked: bool) -> Control:
	var hidden := achievement.secret and not unlocked
	var frame := PanelContainer.new()
	frame.focus_mode = FOCUS_ALL
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	frame.add_child(row)
	var icon := TextureRect.new()
	icon.texture = achievement.get_icon(achievements.database)
	icon.custom_minimum_size = Vector2(52, 52)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = Color.WHITE if unlocked else (Color(0, 0, 0, 0.85) if hidden else Color(1, 1, 1, 0.3))
	row.add_child(icon)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(texts)
	var title := Label.new()
	title.text = "???" if hidden else achievement.get_title()
	title.add_theme_font_size_override(&"font_size", 18)
	texts.add_child(title)
	var description := Label.new()
	description.text = AKText.t("A secret achievement.") if hidden else AKText.t(achievement.description)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.modulate = Color(1, 1, 1, 0.75)
	texts.add_child(description)
	if not unlocked and achievement.goal > 1 and not hidden:
		var bar := ProgressBar.new()
		bar.max_value = achievement.goal
		bar.value = achievements.get_progress(achievement.id)
		bar.custom_minimum_size = Vector2(0, 12)
		bar.show_percentage = false
		bar.tooltip_text = "%d / %d" % [bar.value, achievement.goal]
		texts.add_child(bar)
		var count := Label.new()
		count.text = "%d / %d" % [bar.value, achievement.goal]
		count.modulate = Color(1, 1, 1, 0.6)
		texts.add_child(count)
	var side := VBoxContainer.new()
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(side)
	var points := Label.new()
	points.text = "%d %s" % [achievement.points, AKText.t("pts")]
	points.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	points.modulate = Color(1.0, 0.85, 0.35) if unlocked else Color(1, 1, 1, 0.45)
	side.add_child(points)
	if not achievement.rewards.is_empty() and not hidden:
		if achievements.can_claim(achievement.id):
			var claim := Button.new()
			claim.text = AKText.t("Claim reward")
			var achievement_id := achievement.id
			claim.pressed.connect(func() -> void: _claim(achievement_id))
			side.add_child(claim)
		else:
			var reward := Label.new()
			reward.text = AKText.t("Reward claimed") if achievements.is_claimed(achievement.id) else _reward_text(achievement)
			reward.modulate = Color(1, 1, 1, 0.6)
			side.add_child(reward)
	return frame


func _reward_text(achievement: AKAchievement) -> String:
	var parts := PackedStringArray()
	for item_id in achievement.rewards:
		var definition := achievements.database.get_item(item_id) if achievements.database != null else null
		parts.append("%d × %s" % [achievement.rewards[item_id], IKText.item_name(definition)])
	return "%s %s" % [AKText.t("Reward:"), ", ".join(parts)]


func _claim(achievement_id: StringName) -> void:
	var achievement := achievements.list.get_achievement(achievement_id)
	var result := achievements.claim(achievement_id, bag)
	if result.ok:
		_status.text = "%s: %s" % [achievement.get_title(), AKText.t("reward added to your bag.")]
		_status.modulate = Color(0.6, 1, 0.65)
		claimed.emit(achievement)
	else:
		var text := IKText.result_message(result)
		_status.text = text
		_status.modulate = Color(1, 0.62, 0.52)
		refused.emit(achievement, text)


func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed(&"ui_cancel"):
		close_requested.emit()
		accept_event()


func _queue_refresh() -> void:
	if _refresh_queued:
		return
	_refresh_queued = true
	refresh.call_deferred()
