extends RefCounted

# Read-only projection of the existing session history. No second save file.
static func median(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var sorted: Array = values.duplicate()
	sorted.sort()
	var middle: int = sorted.size()/2
	return float(sorted[middle]) if sorted.size()%2 else (float(sorted[middle-1])+float(sorted[middle]))/2.0

static func usable(data: Dictionary) -> bool:
	var context: Dictionary = data.get("session_context",{})
	if not context.get("parameters_unchanged",false) or context.get("initial",{}).get("signature","") == "":
		return false
	if data.get("parameter_changes",[]).size() > 1:
		return false
	var stationary: bool = data.has("task") or int(data.get("mode",0)) in [1,2,3] or (int(data.get("mode",0)) == 4 and not data.get("alternating_strafe",false))
	return not stationary or (float(context.get("maximum_horizontal_offset_m",999)) <= 0.3 and float(context.get("airborne_seconds",999)) < 0.05 and float(context.get("crouched_seconds",999)) < 0.05)

static func compatible(current: Dictionary, previous: Dictionary) -> bool:
	if not usable(current) or not usable(previous):
		return false
	if current.session_context.initial.signature != previous.session_context.initial.signature:
		return false
	for key in ["task","mode","seed","difficulty","variant","target_radius","target_distance","grid_columns","grid_rows","grid_spacing","show_viewmodel","gap_width_m","direction_mode","base_target_speed_mps","actual_target_speed_mps","rail_half_width_m","target_depth_m","required_zone","alternating_strafe","movement_variant","movement_layout_revision","target_sequence","initial_target_layout"]:
		if not same_value(current.get(key),previous.get(key)):
			return false
	var current_weapons: Array = current.get("weapon_shots",{}).keys()
	var old_weapons: Array = previous.get("weapon_shots",{}).keys()
	current_weapons.sort()
	old_weapons.sort()
	return current_weapons == old_weapons

static func same_value(a: Variant, b: Variant) -> bool:
	if typeof(a) in [TYPE_INT,TYPE_FLOAT] and typeof(b) in [TYPE_INT,TYPE_FLOAT]:
		return float(a) == float(b)
	if typeof(a) != typeof(b):
		return false
	if a is Array:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not same_value(a[i],b[i]):
				return false
		return true
	return a == b

static func matching(history: Array, current: Dictionary, level: int, seconds: float, maximum: int = 5) -> Array:
	var found: Array = []
	for i in range(history.size()-1,-1,-1):
		if not history[i] is Dictionary:
			continue
		var entry: Dictionary = history[i]
		if int(entry.get("level",-1)) != level or not entry.get("drill_metrics") is Dictionary:
			continue
		if int(entry.get("shots",0)) <= 0:
			continue
		if int(current.get("mode",0)) == 6:
			if int(entry.get("kills",0)) != 3:
				continue
		elif absf(float(entry.get("seconds",0))-seconds) > 0.15:
			continue
		if compatible(current,entry.drill_metrics):
			found.append(entry)
			if found.size() >= maximum:
				break
	return found

static func summary(history: Array, current: Dictionary, level: int, seconds: float) -> String:
	if not usable(current):
		return "本轮条件有变化，未加入同条件对照。历史原始记录仍保留。"
	var records: Array = matching(history,current,level,seconds)
	if records.is_empty():
		return "暂无同条件历史。复练后显示最近五轮对照；不同靶型、武器与参数分开比较。"
	var first: Array = []
	var second: Array = []
	var label: String = ""
	for record in records:
		var data: Dictionary = record.drill_metrics
		var accuracy: float = float(record.get("hits",0))/maxf(1.0,float(record.get("shots",0)))
		if current.has("task"):
			first.append(float(data.successful_clicks)/maxf(0.001,float(record.seconds)))
			second.append(accuracy*100.0)
			label = "有效命中 %.2f 次/秒 · 准确率 %.1f%%"
		elif int(current.mode) in [1,2]:
			first.append(float(data.tracking_ratio)*100.0)
			second.append(accuracy*100.0)
			label = "准心在靶 %.1f%% · 子弹命中率 %.1f%%"
		elif int(current.mode) == 3:
			first.append(float(data.successful_trials)/maxf(1.0,float(data.opportunities))*100.0)
			if not data.reaction_ms.is_empty():
				second.append(median(data.reaction_ms))
			label = "命中机会 %.1f%% · 首发延迟 %.0f ms"
		elif int(current.mode) == 4:
			first.append(data.switch_latencies_ms.size())
			second.append(data.wrong_target_hits)
			label = "有效转移 %.1f 次 · 误打其他靶 %.1f 次"
		elif int(current.mode) == 5:
			first.append(data.movement_successes)
			second.append(float(data.stopped_shots)/maxf(1.0,data.shot_speeds.size())*100.0)
			label = "完整动作 %.1f 次 · 停稳开火 %.1f%%"
		else:
			var errors: Array = []
			for value in data.clearance_first_seen.values():
				errors.append(value.angular_error_deg)
			first.append(median(errors))
			second.append(record.seconds)
			label = "首见误差 %.2f° · 清除用时 %.2f 秒"
	if int(current.get("mode",0)) == 3 and second.is_empty():
		return "前 %d 轮同条件中位数：命中机会 %.1f%% · 首发延迟 —" % [records.size(),median(first)]
	return "前 %d 轮同条件中位数：" % records.size() + label % [median(first),median(second)]
