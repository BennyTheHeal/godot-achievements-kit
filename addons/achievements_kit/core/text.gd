class_name AKText
extends RefCounted
## Every text Achievements Kit shows to players goes through here, so it can be translated
## or reworded with Godot's translation system (template:
## [code]addons/achievements_kit/translations/achievements_kit.csv[/code]).


static func t(text: String) -> String:
	if text.is_empty():
		return text
	return String(TranslationServer.translate(text))
