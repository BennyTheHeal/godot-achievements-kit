extends "res://tests/achievements_kit/ak_test_case.gd"
## Stats, unlocks, item stats, rewards, secrets, platform bridge, saving.


func test_stats_unlock_achievements() -> void:
	var achievements := make_achievements(make_db())
	var unlocked := []
	achievements.unlocked.connect(func(a: AKAchievement) -> void: unlocked.append(a.id))
	achievements.add_stat(&"wolves")
	achievements.add_stat(&"wolves")
	assert_eq(achievements.get_progress(&"hunter"), 2)
	assert_false(achievements.is_unlocked(&"hunter"))
	achievements.add_stat(&"wolves")
	assert_true(achievements.is_unlocked(&"hunter"))
	assert_true(achievements.get_unlock_time(&"hunter") > 0)
	achievements.add_stat(&"wolves", 5)
	assert_eq(unlocked, [&"hunter"], "unlocked once")


func test_keep_highest() -> void:
	var achievements := make_achievements(make_db())
	achievements.set_stat(&"gold_held", 80, true)
	achievements.set_stat(&"gold_held", 20, true)
	assert_eq(achievements.get_stat(&"gold_held"), 80)
	achievements.set_stat(&"gold_held", 120, true)
	assert_true(achievements.is_unlocked(&"rich"))


func test_item_stats_from_a_container() -> void:
	var db := make_db()
	var achievements := make_achievements(db)
	var bag := IKContainer.new(&"bag", 4, db)
	achievements.watch_items(bag)
	bag.add(&"wood", 5)
	assert_true(achievements.is_unlocked(&"first_wood"))
	bag.remove(&"wood", 5)
	bag.add(&"wood", 15)
	assert_eq(achievements.get_stat(&"item:wood"), 20, "gains count, losses do not")
	assert_true(achievements.is_unlocked(&"lumberjack"))


func test_manual_and_secret() -> void:
	var achievements := make_achievements(make_db())
	assert_true(achievements.unlock(&"secret"))
	assert_false(achievements.unlock(&"secret"), "already unlocked")
	assert_false(achievements.unlock(&"nope"))
	assert_eq(achievements.get_points(), 10)


func test_claim_rewards_all_or_nothing() -> void:
	var db := make_db()
	var achievements := make_achievements(db)
	achievements.set_stat(&"item:wood", 20)
	var full := IKContainer.new(&"full", 1, db)
	full.add(&"wood", 50)
	assert_true(achievements.can_claim(&"lumberjack"))
	assert_false(achievements.claim(&"lumberjack", full).ok, "no room")
	assert_true(achievements.can_claim(&"lumberjack"), "the reward waits")
	var bag := IKContainer.new(&"bag", 2, db)
	assert_true(achievements.claim(&"lumberjack", bag).ok)
	assert_eq(bag.count(&"potion"), 2)
	assert_false(achievements.can_claim(&"lumberjack"))
	assert_false(achievements.claim(&"lumberjack", bag).ok, "claimed once")
	assert_false(achievements.can_claim(&"hunter"), "locked, and no reward")


func test_platform_bridge() -> void:
	var achievements := make_achievements(make_db())
	var bridge := RecordingBridge.new()
	achievements.bridge = bridge
	achievements.add_stat(&"wolves", 3)
	assert_eq(bridge.calls, [["stat", &"wolves", 3], ["unlock", "hunter"], ["store"]])
	assert_false(AKSteamBridge.new().is_available(), "no GodotSteam in the tests: the Steam bridge stays silent")
	AKSteamBridge.new().unlock("anything")  # must not error


func test_save_and_load() -> void:
	var db := make_db()
	var achievements := make_achievements(db)
	achievements.add_stat(&"wolves", 2)
	achievements.set_stat(&"item:wood", 25)
	var bag := IKContainer.new(&"bag", 2, db)
	achievements.claim(&"lumberjack", bag)
	var data: Dictionary = JSON.parse_string(JSON.stringify(achievements.to_data()))
	var copy := make_achievements(db)
	var signals := []
	copy.unlocked.connect(func(a: AKAchievement) -> void: signals.append(a.id))
	assert_true(copy.load_data(data))
	assert_eq(copy.get_stat(&"wolves"), 2)
	assert_true(copy.is_unlocked(&"lumberjack"))
	assert_true(copy.is_claimed(&"lumberjack"))
	assert_eq(signals, [], "restored unlocks make no noise")
	assert_false(copy.load_data({"stats": 1}))


func test_new_achievement_counts_past_progress() -> void:
	var achievements := make_achievements(make_db())
	achievements.add_stat(&"fish", 12)
	var data := achievements.to_data()
	var updated := make_achievements(make_db())
	updated.list.add(AKAchievement.make(&"angler", "Angler", &"fish", 10))
	updated.load_data(data)
	assert_true(updated.is_unlocked(&"angler"), "added in an update, already earned")


func test_list_validation() -> void:
	var db := make_db()
	var list := make_list()
	assert_eq(list.validate(db), PackedStringArray())
	var broken := AKAchievement.make(&"first_wood", "Dup", &"", 1, &"crown")
	broken.rewards = {&"crown": 1}
	list.add(broken)
	assert_eq(list.validate(db).size(), 3, str(list.validate(db)))


func test_progress_milestones() -> void:
	var achievements := AKAchievements.new()
	achievements.list = make_list()
	achievements.progress_percents = PackedInt32Array([25, 50, 75])
	add_to_tree(achievements)
	var steps := []
	achievements.progress_reached.connect(func(a: AKAchievement, value: int, goal: int) -> void: steps.append([a.id, value, goal]))
	achievements.add_stat(&"item:wood", 4)   # first_wood unlocks (goal 1: no step); lumberjack 4/20
	achievements.add_stat(&"item:wood", 1)   # 5/20 = 25 %
	achievements.add_stat(&"item:wood", 9)   # 14/20: 50 % and 75 % crossed at once, one toast
	achievements.add_stat(&"item:wood", 10)  # unlocked: no progress step
	assert_eq(steps, [[&"lumberjack", 5, 20], [&"lumberjack", 14, 20]])
	var hunter := achievements.list.get_achievement(&"hunter")
	hunter.progress_milestones = PackedInt32Array([2])
	achievements.add_stat(&"wolves", 2)
	assert_eq(steps.back(), [&"hunter", 2, 3], "an achievement's own milestones win")
	assert_eq(hunter.get_milestones(PackedInt32Array([50])), PackedInt32Array([2]))
	assert_eq(AKAchievement.make(&"x", "X", &"s", 100).get_milestones(PackedInt32Array([50, 10, 100])), PackedInt32Array([10, 50]), "sorted, below the goal")
	steps.clear()
	achievements.set_stat(&"gold_held", 60)
	achievements.list.get_achievement(&"rich").secret = true
	achievements.set_stat(&"gold_held", 90)
	assert_eq(steps, [[&"rich", 60, 100]], "secret achievements never show progress")
	disconnect_all([achievements])


func test_progress_is_off_by_default() -> void:
	var achievements := make_achievements(make_db())
	var steps := []
	achievements.progress_reached.connect(func(a: AKAchievement, _v: int, _g: int) -> void: steps.append(a.id))
	achievements.add_stat(&"item:wood", 15)
	assert_eq(steps, [], "1.0 behaviour: unlock toasts only")
	disconnect_all([achievements])


func test_auto_save_and_load() -> void:
	var path := "user://ak_tests/slot1/achievements.save"
	DirAccess.remove_absolute(path)
	var achievements := AKAchievements.new()
	achievements.list = make_list()
	achievements.auto_save = true
	achievements.save_path = path
	add_to_tree(achievements)
	assert_false(FileAccess.file_exists(path), "nothing saved before a change")
	achievements.add_stat(&"wolves", 2)
	achievements.add_stat(&"wolves", 1)  # unlocks hunter, same frame: one write
	await wait_frames(1)
	assert_true(FileAccess.file_exists(path), "saved after the change")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert_eq(int(data.stats.wolves), 3)
	assert_true(data.unlocked.has("hunter"))
	assert_false(FileAccess.file_exists(path + ".tmp"), "no temporary file left")
	var next_run := AKAchievements.new()
	next_run.list = make_list()
	next_run.auto_save = true
	next_run.save_path = path
	add_to_tree(next_run)
	assert_eq(next_run.get_stat(&"wolves"), 3, "loaded when ready")
	assert_true(next_run.is_unlocked(&"hunter"))
	next_run.unlock(&"secret")
	next_run.free()  # leaving the tree flushes a pending save
	var reloaded := AKAchievements.new()
	reloaded.list = make_list()
	reloaded.save_path = path
	assert_true(reloaded.load_local())
	assert_true(reloaded.is_unlocked(&"secret"))
	reloaded.delete_local()
	assert_false(FileAccess.file_exists(path))
	assert_false(reloaded.load_local(), "no file: nothing loaded")
	reloaded.free()


func test_auto_save_is_off_by_default() -> void:
	var achievements := make_achievements(make_db())
	assert_false(achievements.auto_save)
	assert_eq(achievements.save_path, "user://achievements.save")
	DirAccess.remove_absolute("user://achievements.save")
	achievements.add_stat(&"wolves", 3)
	await wait_frames(1)
	assert_false(FileAccess.file_exists("user://achievements.save"))
