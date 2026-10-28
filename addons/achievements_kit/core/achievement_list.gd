@tool
class_name AKAchievementList
extends Resource
## Every achievement of the game. Save it as a .tres.

@export var achievements: Array[AKAchievement] = []

var _index: Dictionary = {}
var _indexed_count := -1


func get_achievement(achievement_id: StringName) -> AKAchievement:
	if _indexed_count != achievements.size():
		_index.clear()
		for achievement in achievements:
			if achievement != null and not achievement.id.is_empty():
				_index[achievement.id] = achievement
		_indexed_count = achievements.size()
	return _index.get(achievement_id)


func add(achievement: AKAchievement) -> void:
	achievements.append(achievement)
	_indexed_count = -1


func validate(database: IKItemDatabase) -> PackedStringArray:
	var problems := PackedStringArray()
	var seen := {}
	for achievement in achievements:
		if achievement == null:
			problems.append("empty slot in the achievement list")
			continue
		if achievement.id.is_empty() or seen.has(achievement.id):
			problems.append("achievement id missing or duplicated: '%s'" % achievement.id)
		seen[achievement.id] = true
		for item_id in achievement.rewards:
			if database != null and not database.has_item(item_id):
				problems.append("%s: unknown reward item %s" % [achievement.id, item_id])
		if database != null and not achievement.icon_item.is_empty() and not database.has_item(achievement.icon_item):
			problems.append("%s: unknown icon item %s" % [achievement.id, achievement.icon_item])
	return problems
