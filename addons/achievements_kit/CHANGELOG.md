# Changelog

All notable changes to Achievements Kit are documented here. Versions follow [Semantic Versioning](https://semver.org/).

## [1.1.0] - 2026-10-28

### Added
- Local save for games outside Steam: `AKAchievements.auto_save` (off by default) and `save_path` (default `user://achievements.save`). Saves after every unlock, progress step and claim (once per frame at most, through a temporary file), loads when the node is ready, flushes on quit. `save_local()`, `load_local()`, `delete_local()`, signal `saved(error)`.
- Progress notifications: `AKAchievements.progress_percents` (e.g. `[25, 50, 75]`) and `AKAchievement.progress_milestones`; signal `progress_reached(achievement, value, goal)`; `AKToast` shows "Title 50/100" with a bar (`show_progress_toasts`, `progress_duration`). Never for secret achievements.
- README: the Steam bridge up front, and a guide with skeletons for Epic, GOG, a server, and several platforms at once.
- Demo: progress toasts and an Auto-save switch. 17 automated tests.

### Compatibility
- Same save format (version 1). Without the new settings, the kit behaves exactly like 1.0 (no progress toasts, no file written).

## [1.0.0] - 2026-10-26

### Added
- `AKAchievement`, `AKAchievementList`: achievements as resources (stat and goal, icon from the item database, points, secret, rewards, platform name) with validation.
- `AKAchievements`: stats (add, set, keep highest), item stats from watched containers, automatic and manual unlocks, rewards claimed in one Inventory Kit transaction, points, save / load (new achievements count past progress).
- `AKPlatformBridge` and `AKSteamBridge` (GodotSteam, optional).
- `AKToast` and `AKAchievementsWindow`.
- Demo with eight achievements in the four Inventory Kit art styles; 12 automated tests; translation template.
