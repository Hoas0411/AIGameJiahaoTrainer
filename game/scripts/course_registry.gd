extends RefCounted

# Stable IDs preserve saved histories; only these scenes are selectable/exported.
const ACTIVE_IDS = [0, 6, 7, 8, 12, 13, 15, 19, 20]
const TRAINING_IDS = [0,19,15,13,6,7,8,20]
const PENDING_IDS = [6,7,8,15,19]
const NAMES = ["AWM镭射", "", "", "", "", "", "距离与控枪", "Valorant随机反应", "高低差转移", "", "", "", "基地", "跟随移动射击", "", "架门缝", "", "", "", "三球定位", "掩体分段射击", "", ""]
const SCENES = {
	0: preload("res://scenes/levels/awm_endwall_symmetry_20261005/runtime.tscn"),
	6: preload("res://scenes/levels/07_range.tscn"),
	7: preload("res://scenes/levels/08_reaction.tscn"),
	8: preload("res://scenes/levels/09_elevation.tscn"),
	12: preload("res://scenes/levels/circular_lobby_fit/circular_lobby.tscn"),
	13: preload("res://scenes/levels/training/14_smooth_tracking.tscn"),
	15: preload("res://scenes/levels/training/16_mid_doors.tscn"),
	19: preload("res://scenes/levels/training/20_gridshot.tscn"),
	20: preload("res://scenes/levels/segmented_cover_20261005/runtime.tscn"),
}
