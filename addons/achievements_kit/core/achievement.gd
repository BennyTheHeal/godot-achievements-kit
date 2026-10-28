@tool
class_name AKAchievement
extends Resource
## One achievement: a stat to reach (or a manual unlock), how it looks, what it gives.

## Stable id, stored in save files. Pick it once and never change it.
@export var id: StringName
@export var title: String = ""
@export_multiline var description: String = ""
## Stat followed ([method AKAchievements.add_stat]). Empty = unlocked only by [method AKAchievements.unlock].
@export var stat: StringName
## Stat value to reach.
@export_range(1, 1000000) var goal: int = 1
@export_group("Look")
## Icon. Empty = the icon of [member icon_item] from the item database.
@export var icon: Texture2D
@export var icon_item: StringName
@export var category: StringName
@export var points: int = 10
## Hidden as "???" until unlocked.
@export var secret: bool = false
@export_group("Reward")
## Items the player can claim once unlocked, {item_id: amount}.
@export var rewards: Dictionary[StringName, int] = {}
@export_group("Progress")
## Stat values that show a progress toast ("50/100"), e.g. [10, 50]. Empty = the
## [member AKAchievements.progress_percents] of the goal. Never shown for secret achievements.
@export var progress_milestones: PackedInt32Array = []
@export_group("Platforms")
## Achievement API name on Steam (or another platform). Empty = the id.
@export var platform_name: String = ""


static func make(p_id: StringName, p_title: String, p_stat: StringName = &"", p_goal: int = 1, p_icon_item: StringName = &"") -> AKAchievement:
	var achievement := AKAchievement.new()
	achievement.id = p_id
	achievement.title = p_title
	achievement.stat = p_stat
	achievement.goal = p_goal
	achievement.icon_item = p_icon_item
	return achievement


func get_title() -> String:
	return AKText.t(title) if not title.is_empty() else String(id).capitalize()


func get_icon(database: IKItemDatabase) -> Texture2D:
	if icon != null:
		return icon
	var definition := database.get_item(icon_item) if database != null and not icon_item.is_empty() else null
	return definition.icon if definition != null else null


## Stat values that notify progress: [member progress_milestones], or [param percents] of
## the goal (rounded, at least 1, always below the goal).
func get_milestones(percents: PackedInt32Array = PackedInt32Array()) -> PackedInt32Array:
	var values := PackedInt32Array()
	if not progress_milestones.is_empty():
		for value in progress_milestones:
			if value > 0 and value < goal and not values.has(value):
				values.append(value)
	else:
		for percent in percents:
			var value := maxi(1, roundi(goal * percent / 100.0))
			if percent > 0 and value < goal and not values.has(value):
				values.append(value)
	values.sort()
	return values


func get_platform_name() -> String:
	return platform_name if not platform_name.is_empty() else String(id)
