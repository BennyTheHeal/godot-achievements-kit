extends IKInventoryUI
## Achievements Kit demo: an adventure in six buttons. Chop, hunt, mine, sell, explore and
## pet the dog to unlock eight achievements (stats, item stats, "most gold held", a secret
## one), watch the toasts, claim rewards, save / load, switch art directions.

const ART := "res://addons/inventory_kit/art/"
const DIRECTIONS := {"painted": "Hand-painted", "realistic": "Realistic", "cartoon": "Cartoon", "flat": "Flat"}
const SAVE_DIR := "user://achievements_demo/"
const SITE := "https://banc-essai.site-testeurs.workers.dev/?src=achievements-demo"
const PLACES: Array[String] = ["the Old Forest", "the River Ford", "the Ruins", "the Grey Mountain"]

var bag: IKInventory
var achievements: AKAchievements
var window: AKAchievementsWindow
var toast: AKToast
var art_direction := ""
var _picker: OptionButton
var _status: Label
var _rng := RandomNumberGenerator.new()
var _visited: Array[String] = []
var _save := IKSaveFile.new(SAVE_DIR + "inventory.json")


static func available_directions() -> Array[String]:
	var result: Array[String] = []
	for da in DIRECTIONS:
		if ResourceLoader.exists(ART + "%s/%s_items.tres" % [da, da]):
			result.append(da)
	return result


static func make_list() -> AKAchievementList:
	var list := AKAchievementList.new()
	_add(list, &"first_chop", "First Chop", "Chop your first oak log.", &"item:oak_log", 1, &"oak_log", 5)
	_add(list, &"lumberjack", "Lumberjack", "Gather 30 oak logs.", &"item:oak_log", 30, &"axe", 15, {&"iron_ingot": 2})
	_add(list, &"wolf_hunter", "Wolf Hunter", "Drive off 5 wolves.", &"wolves", 5, &"bow", 15, {&"health_potion": 2})
	_add(list, &"pack_leader", "Pack Leader", "Drive off 20 wolves.", &"wolves", 20, &"scaled_hide", 30)
	_add(list, &"gem_finder", "Gem Finder", "Find 3 rubies.", &"item:ruby", 3, &"ruby", 15)
	_add(list, &"pocket_money", "Pocket Money", "Hold 200 gold coins at once.", &"gold_held", 200, &"gold_coins", 10)
	_add(list, &"explorer", "Explorer", "Visit the four corners of the map.", &"places", 4, &"map", 20, {&"gold_coins": 50})
	var dog := _add(list, &"good_boy", "Good Boy", "You petted the dog. Of course you did.", &"", 1, &"bone", 10)
	dog.secret = true
	return list


static func _add(list: AKAchievementList, id: StringName, title: String, description: String, stat: StringName,
		goal: int, icon_item: StringName, points: int, rewards: Dictionary = {}) -> AKAchievement:
	var achievement := AKAchievement.make(id, title, stat, goal, icon_item)
	achievement.description = description
	achievement.points = points
	achievement.rewards.assign(rewards)
	list.add(achievement)
	return achievement


func _ready() -> void:
	_rng.seed = 7
	var directions := available_directions()
	var database: IKItemDatabase = load(ART + "%s/%s_items.tres" % [directions[0], directions[0]])
	bag = IKInventory.new()
	bag.name = "Bag"
	bag.container_id = &"bag"
	bag.size = 12
	bag.database = database
	bag.initial_items.assign({&"gold_coins": 60})
	add_child(bag)
	achievements = AKAchievements.new()
	achievements.name = "Achievements"
	achievements.list = make_list()
	achievements.database = database
	achievements.bridge = AKSteamBridge.new()  # silent without GodotSteam
	achievements.progress_percents = PackedInt32Array([25, 50, 75])  # "Lumberjack 15/30" toasts
	achievements.save_path = SAVE_DIR + "auto.save"  # auto_save stays off until the checkbox
	add_child(achievements)
	_build_layout(directions)
	super._ready()
	achievements.watch_items(bag.container)
	bag.container.changed.connect(func() -> void:
		achievements.set_stat(&"gold_held", bag.container.count(&"gold_coins"), true))
	window.achievements = achievements
	window.bag = bag.container
	toast.achievements = achievements
	interaction_failed.connect(func(result: IKResult) -> void: _set_status(IKText.result_message(result), true))
	apply_art_direction(directions[0])


func apply_art_direction(da: String) -> void:
	art_direction = da
	var database: IKItemDatabase = load(ART + "%s/%s_items.tres" % [da, da])
	bag.container.database = database
	cursor.container.database = database
	achievements.database = database
	theme = load(ART + "%s/%s_theme.tres" % [da, da])
	skin = load(ART + "%s/%s_skin.tres" % [da, da])
	toast.add_theme_stylebox_override(&"panel", theme.get_stylebox(&"panel", &"TooltipPanel"))
	window.refresh()
	var index := available_directions().find(da)
	if _picker != null and index >= 0 and _picker.selected != index:
		_picker.select(index)


func do_action(action: StringName) -> void:
	match action:
		&"chop":
			_give(&"oak_log", 3, "You chop 3 oak logs.")
		&"hunt":
			achievements.add_stat(&"wolves")
			_give(&"rawhide", 1, "You drive off a wolf (%d so far)." % achievements.get_stat(&"wolves"))
		&"mine":
			if _rng.randf() < 0.4:
				_give(&"ruby", 1, "A ruby glints in the rock!")
			else:
				_give(&"stone", 2, "Just stone this time.")
		&"sell":
			if bag.container.has(&"oak_log", 5):
				var result := IKTransaction.new().consume(bag.container, {&"oak_log": 5}).add(bag.container, &"gold_coins", 40).commit()
				_set_status("You sell 5 oak logs for 40 gold." if result.ok else IKText.result_message(result), not result.ok)
			else:
				_set_status("You need 5 oak logs to sell.", true)
		&"explore":
			var place := PLACES[_visited.size() % PLACES.size()]
			if not _visited.has(place):
				_visited.append(place)
				achievements.add_stat(&"places")
			_set_status("You explore %s." % place)
		&"dog":
			achievements.unlock(&"good_boy")
			_set_status("The village dog wags its tail.")


func _give(item_id: StringName, amount: int, text: String) -> void:
	var result := bag.container.add(item_id, amount)
	_set_status(text if result.ok else IKText.result_message(result), not result.ok)


func _build_layout(directions: Array[String]) -> void:
	var background := ColorRect.new()
	background.color = Color(0.07, 0.08, 0.10)
	background.mouse_filter = MOUSE_FILTER_IGNORE
	background.set_anchors_preset(PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(PRESET_FULL_RECT)
	margin.mouse_filter = MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 8)
	margin.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override(&"separation", 10)
	column.add_child(header)
	var title := Label.new()
	title.text = "Achievements Kit — demo"
	title.add_theme_font_size_override(&"font_size", 22)
	header.add_child(title)
	_picker = OptionButton.new()
	for da in directions:
		_picker.add_item(DIRECTIONS[da])
	_picker.item_selected.connect(func(index: int) -> void: apply_art_direction(directions[index]))
	_picker.focus_mode = FOCUS_NONE
	header.add_child(_picker)
	_button(header, "Save", _on_save)
	_button(header, "Load", _on_load)
	var auto := CheckButton.new()
	auto.text = "Auto-save"
	auto.tooltip_text = "Saves achievements to user://achievements_demo/auto.save after every unlock and progress step."
	auto.focus_mode = FOCUS_NONE
	auto.toggled.connect(set_auto_save)
	header.add_child(auto)
	var site := LinkButton.new()
	site.text = "More kits & our games »"
	site.uri = SITE
	site.size_flags_vertical = SIZE_SHRINK_CENTER
	header.add_child(site)

	var body := HBoxContainer.new()
	body.add_theme_constant_override(&"separation", 14)
	body.size_flags_vertical = SIZE_EXPAND_FILL
	column.add_child(body)
	var left := VBoxContainer.new()
	left.add_theme_constant_override(&"separation", 8)
	body.add_child(left)
	var actions := PanelContainer.new()
	left.add_child(actions)
	var grid := GridContainer.new()
	grid.columns = 2
	actions.add_child(grid)
	for action in [[&"chop", "Chop wood"], [&"hunt", "Hunt a wolf"], [&"mine", "Mine for gems"],
			[&"sell", "Sell 5 logs"], [&"explore", "Explore"], [&"dog", "Pet the dog"]]:
		var action_id: StringName = action[0]
		_button(grid, action[1], func() -> void: do_action(action_id))
		grid.get_child(-1).custom_minimum_size = Vector2(180, 0)
	var bag_frame := PanelContainer.new()
	left.add_child(bag_frame)
	var bag_box := VBoxContainer.new()
	bag_frame.add_child(bag_box)
	var bag_label := Label.new()
	bag_label.text = "Your bag"
	bag_box.add_child(bag_label)
	var view := IKContainerView.new()
	view.name = "BagView"
	view.columns = 6
	view.inventory = bag
	bag_box.add_child(view)
	_status = Label.new()
	_status.text = "Play around: every action counts toward something."
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(380, 0)
	left.add_child(_status)

	window = AKAchievementsWindow.new()
	window.name = "AchievementsWindow"
	window.size_flags_horizontal = SIZE_EXPAND_FILL
	window.size_flags_vertical = SIZE_EXPAND_FILL
	window.close_requested.connect(func() -> void: _set_status("Cancel in the window: a game would close it here."))
	body.add_child(window)

	toast = AKToast.new()
	toast.name = "Toast"
	toast.set_anchors_and_offsets_preset(PRESET_BOTTOM_LEFT)
	toast.grow_vertical = GROW_DIRECTION_BEGIN
	toast.offset_left = 16
	toast.offset_bottom = -16
	add_child(toast)


## The local save of games without Steam: on = saved after every change, loaded at start.
func set_auto_save(enabled: bool) -> void:
	achievements.auto_save = enabled
	if enabled:
		achievements.save_local()
		_set_status("Auto-save on: %s is written after every unlock and progress step." % achievements.save_path)
	else:
		_set_status("Auto-save off.")


func _button(parent: Control, text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.focus_mode = FOCUS_NONE
	button.pressed.connect(callback)
	parent.add_child(button)


func _on_save() -> void:
	return_held()
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var error := _save.save([bag.container])
	var file := FileAccess.open(SAVE_DIR + "achievements.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"achievements": achievements.to_data(), "visited": _visited}, "\t"))
	_set_status("Saved: bag, stats and achievements." if error == OK and file != null else "Save failed.", error != OK or file == null)


func _on_load() -> void:
	return_held()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_DIR + "achievements.json"))
	if typeof(parsed) != TYPE_DICTIONARY or typeof(parsed.get("achievements")) != TYPE_DICTIONARY:
		_set_status("Nothing to load yet: press Save first.", true)
		return
	var report := _save.load_into([bag.container])
	if not report.ok:
		_set_status(report.error, true)
		return
	achievements.load_data(parsed.achievements)
	_visited.assign(parsed.get("visited", []))
	_set_status("Loaded.")


func _set_status(text: String, warning: bool = false) -> void:
	_status.text = text
	_status.modulate = Color(1, 0.6, 0.5) if warning else Color(0.7, 1, 0.7)
