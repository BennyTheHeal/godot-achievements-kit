extends "res://tests/achievements_kit/ak_test_case.gd"
## The achievements window, the toast and the demo scene.


func test_window_lists_filters_and_claims() -> void:
	var db := make_db()
	var achievements := make_achievements(db)
	var bag := IKContainer.new(&"bag", 4, db)
	var window := AKAchievementsWindow.new()
	window.achievements = achievements
	window.bag = bag
	add_to_tree(window)
	await wait_frames(2)
	assert_eq(window._rows.get_child_count(), 5)
	achievements.set_stat(&"item:wood", 20)
	await wait_frames(2)
	window.set_filter(AKAchievementsWindow.Filter.UNLOCKED)
	assert_eq(window._rows.get_child_count(), 2)
	window.set_filter(AKAchievementsWindow.Filter.LOCKED)
	assert_eq(window._rows.get_child_count(), 3)
	window._claim(&"lumberjack")
	assert_eq(bag.count(&"potion"), 2)
	assert_true(window._summary.text.begins_with("2 / 5"), window._summary.text)


func test_toast_queues_unlocks() -> void:
	var achievements := make_achievements(make_db())
	var toast := AKToast.new()
	toast.achievements = achievements
	toast.duration = 0.05
	add_to_tree(toast)
	await wait_frames(1)
	achievements.unlock(&"secret")
	achievements.unlock(&"hunter")
	assert_true(toast.visible)
	assert_eq(toast._name.text, "Good boy")
	assert_true(toast.is_busy())
	await get_tree().create_timer(2.0).timeout
	assert_false(toast.is_busy(), "both shown, then hidden")
	assert_false(toast.visible)


func test_demo_runs_in_every_art_direction() -> void:
	var demo: Node = add_to_tree(load("res://demo/achievements/achievements_demo.tscn").instantiate())
	await wait_frames(3)
	assert_eq(demo.achievements.list.validate(demo.achievements.database), PackedStringArray())
	for da in demo.available_directions():
		demo.apply_art_direction(da)
		await wait_frames(1)
	demo.do_action(&"chop")
	assert_true(demo.achievements.is_unlocked(&"first_chop"))
	for i in 5:
		demo.do_action(&"hunt")
	assert_true(demo.achievements.is_unlocked(&"wolf_hunter"))
	demo.do_action(&"dog")
	assert_true(demo.achievements.is_unlocked(&"good_boy"))
	demo._on_save()
	demo.achievements.add_stat(&"wolves", 50)
	demo._on_load()
	assert_eq(demo.achievements.get_stat(&"wolves"), 5, "Load restores the stats")


func test_toast_shows_progress() -> void:
	var achievements := make_achievements(make_db())
	achievements.progress_percents = PackedInt32Array([50])
	var toast := AKToast.new()
	toast.achievements = achievements
	toast.duration = 0.05
	toast.progress_duration = 0.05
	add_to_tree(toast)
	await wait_frames(1)
	achievements.add_stat(&"item:wood", 10)  # first_wood unlocked, lumberjack 10/20
	assert_eq(toast._name.text, "First wood", "the unlock comes first")
	await get_tree().create_timer(2.0).timeout
	assert_false(toast.is_busy())
	assert_eq(toast._name.text, "Lumberjack  10/20")
	assert_eq(toast._title.text, "Achievement progress")
	assert_eq(toast._bar.value, 10.0)
	toast.show_progress_toasts = false
	achievements.progress_percents = PackedInt32Array([75])
	achievements.add_stat(&"item:wood", 6)
	assert_false(toast.is_busy(), "progress toasts can be turned off")
