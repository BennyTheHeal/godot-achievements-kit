# Achievements Kit for Godot 4

Achievements for your game: **stats and goals**, **item stats** counted automatically, secret achievements, **claimable rewards**, **unlock and progress toasts** ("50/100"), a **ready-to-use achievements window**, an **automatic local save** for itch.io and web builds, and a **Steam bridge included**.

**Shipping on Steam?** `AKSteamBridge` is already in the box: one line (`achievements.bridge = AKSteamBridge.new()`) and every unlock and stat goes to Steam through GodotSteam. Without GodotSteam, or outside Steam, it stays silent, so the same build runs on itch.io too. Epic, GOG or your own server: write a small bridge (see "Other platforms" below).

**Pay what you want, from $0.** Code under MIT. A tip on itch.io keeps new kits coming. Official page, downloads and playable web demo: https://banc-essai.site-testeurs.workers.dev/achievements-kit/
More kits, and our game prototypes waiting for testers: https://banc-essai.site-testeurs.workers.dev/

- **Stats**: count anything (`add_stat(&"wolves")`), or keep the highest value (`set_stat(&"gold_held", gold, true)`). Achievements unlock by themselves when their stat reaches the goal; manual unlocks for story moments.
- **Item stats**: `watch_items(bag)` counts every item the player gains (`item:oak_log`), for "Gather 100 logs" without extra code.
- **Rewards**, built on **Inventory Kit** (included in the download): claimed in one atomic transaction. A full bag never loses a reward, it waits to be claimed.
- **Secret** achievements shown as "???", points, categories, icons taken from your item database (the 120 Inventory Kit icons in 4 art styles).
- **AKToast**: "Achievement unlocked" pop-ups, queued, and progress pop-ups ("Lumberjack 15/30" with a bar) at the steps you choose: `progress_percents = [25, 50, 75]` for every goal, or `progress_milestones` per achievement. Never for secret achievements. **AKAchievementsWindow**: totals, All / Unlocked / Locked, progress bars, Claim buttons.
- **Platforms**: `AKSteamBridge` mirrors unlocks and stats to Steam through GodotSteam when it is present (silent otherwise); extend `AKPlatformBridge` for Epic, GOG, consoles or a server.
- **Local save for games outside Steam**: `auto_save = true` writes `user://achievements.save` (or your `save_path`) after every unlock, progress step and claim, and reads it back at start. Written through a temporary file, once per frame at most.
- Saves (`to_data()` / `load_data()`): achievements added in an update count past progress; 1.0 saves load unchanged. Translatable texts, 17 automated tests.

## Install

1. Copy `addons/inventory_kit/` and `addons/achievements_kit/` into your project's `addons/` folder (skip Inventory Kit if you already have it).
2. Open `demo/achievements/achievements_demo.tscn`.

## Five-minute setup

```gdscript
var list := AKAchievementList.new()        # save it as a .tres
var hunter := AKAchievement.make(&"wolf_hunter", "Wolf Hunter", &"wolves", 5, &"bow")
hunter.rewards = {&"health_potion": 2}
list.add(hunter)
list.add(AKAchievement.make(&"lumberjack", "Lumberjack", &"item:oak_log", 30, &"axe"))

var achievements := AKAchievements.new()
achievements.list = list
achievements.bridge = AKSteamBridge.new()  # optional
add_child(achievements)
achievements.watch_items(bag.container)

achievements.add_stat(&"wolves")           # from your game
achievements.claim(&"wolf_hunter", bag.container)
```

Local save and progress toasts (games outside Steam, web builds):

```gdscript
achievements.auto_save = true                          # before add_child: loads at start, saves after every change
achievements.save_path = "user://achievements.save"    # the default; any writable path works
achievements.progress_percents = [25, 50, 75]          # "Wolf Hunter 5/20" toasts
hunter.progress_milestones = [10, 50]                  # or exact steps for one achievement
```

`save_local()`, `load_local()` and `delete_local()` are there if you prefer to decide when; `saved(error)` reports each write.

UI:

```gdscript
var toast := AKToast.new()                 # in your HUD
toast.achievements = achievements

var window := AKAchievementsWindow.new()
window.achievements = achievements
window.bag = bag.container
window.theme = preload("res://addons/inventory_kit/art/painted/painted_theme.tres")
```

## Classes

| Class | Role |
|---|---|
| `AKAchievement`, `AKAchievementList` | Achievements as resources: stat, goal, icon, points, secret, rewards, platform name, validation |
| `AKAchievements` | Stats, unlocks, item stats, rewards (`claim()`), points, save (`to_data()`, or `auto_save` / `save_local()` / `load_local()`), progress steps; signals `unlocked`, `progress_reached`, `stat_changed`, `reward_claimed`, `saved`, `changed` |
| `AKPlatformBridge`, `AKSteamBridge` | Mirror unlocks and stats to a platform |
| `AKToast`, `AKAchievementsWindow` | Unlock and progress pop-ups, the achievements screen |

## Other platforms (Epic, GOG, a server)

A bridge is a small class that receives three calls: `unlock(platform_name)` for each unlock, `set_stat(stat, value)` when a stat changes, and `store()` after a batch. Extend `AKPlatformBridge`, call your platform SDK in each, and keep it silent when the SDK is missing, like `AKSteamBridge` does: the same build then runs everywhere. `platform_name` is the achievement's `platform_name` (or its id): use the API name you created on the platform's dashboard.

```gdscript
class_name MyEpicBridge
extends AKPlatformBridge
## Unlocks on the Epic Games Store through the EOS plugin your game uses.

func is_available() -> bool:
	return Engine.has_singleton("EOS")           # whatever your EOS plugin registers

func unlock(platform_name: String) -> void:
	if is_available():
		pass  # call your EOS plugin: unlock the achievement named platform_name for the logged-in user

func set_stat(stat: StringName, value: int) -> void:
	if is_available():
		pass  # EOS stats are ingested: send (stat, value), or nothing if you only use unlocks

func store() -> void:
	pass      # nothing to do if the SDK writes at once; otherwise flush here
```

The same skeleton works for GOG Galaxy (unlock with the Galaxy binding you use, then store the stats and achievements in `store()`), consoles, or your own server (send an HTTP request in `unlock()`). Several platforms in one build: forward to several bridges.

```gdscript
class_name MultiBridge
extends AKPlatformBridge

var bridges: Array[AKPlatformBridge] = []

func unlock(platform_name: String) -> void:
	for bridge in bridges:
		bridge.unlock(platform_name)

func set_stat(stat: StringName, value: int) -> void:
	for bridge in bridges:
		bridge.set_stat(stat, value)

func store() -> void:
	for bridge in bridges:
		bridge.store()
```

```gdscript
var multi := MultiBridge.new()
multi.bridges = [AKSteamBridge.new(), MyEpicBridge.new()]
achievements.bridge = multi
```

Keep `auto_save` on next to a bridge: the platform shows the trophies, the local save keeps your own stats and the rewards already claimed.

## Running the tests

```bash
godot --headless --path <project> --import
godot --headless --path <project> -s res://tests/achievements_kit/run_tests.gd
```

## Licenses

- Source code: MIT (`LICENSE.txt`).
- The item art in `addons/inventory_kit/art/` is covered by Inventory Kit's `LICENSE_ART.txt`: free to use in your games, please do not re-upload it; link to the official page instead.
- Found a bug or want a feature? Tell us: https://banc-essai.site-testeurs.workers.dev/
