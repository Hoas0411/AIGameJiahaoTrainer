extends CanvasLayer

@onready var game: Node = get_parent()

func _ready() -> void:
	add_to_group("training_modal")
	$Panel/Retry.pressed.connect(func(): hide_panel(); game.start_session(game.level_index))
	$Panel/Catalog.pressed.connect(func(): game.get_node("TrainingCatalog").open())
	$Panel/Hub.pressed.connect(func(): hide_panel(); game.enter_hub())

func hide_panel() -> void:
	$Panel.hide()

func is_open() -> bool:
	return $Panel.visible

func percentile(values: Array, fraction: float) -> String:
	if values.is_empty():
		return "—"
	var sorted: Array = values.duplicate()
	sorted.sort()
	return "%.0f ms" % float(sorted[clampi(ceili(sorted.size()*fraction)-1,0,sorted.size()-1)])

func ratio(numerator: float, denominator: float) -> String:
	return "%.1f%%" % (100.0*numerator/denominator) if denominator > 0 else "—"

func show_for_session() -> void:
	var data: Dictionary = game.level.metrics()
	var cards: Array = []
	var notes: String = ""
	var title: String = game.ui.TITLES[game.level_index]
	$Panel/Title.text = title + " / 本轮成绩"
	$Panel/Subtitle.text = "同难度、同站位和同参数的多轮表现，才适合直接比较。"
	var accuracy: String = ratio(game.hits,game.shots)
	var context: Dictionary = data.get("session_context",{})
	if not context.get("parameters_unchanged",true):
		$Panel/Subtitle.text = "本轮修改过玩家或画面参数，比较成绩时请查看参数记录。"
	elif game.level_index == 19 and context.get("maximum_horizontal_offset_m",0.0) > 0.3:
		$Panel/Subtitle.text = "本轮离开起始站位 %.2f 米；靠近目标会改变难度，请单独比较。" % context.maximum_horizontal_offset_m
	if game.level_index == 19:
		$Panel/Title.text = "Gridshot / " + ("精度加强" if data.variant == "precision" else "参考基准") + " / 本轮成绩"
		cards = [["有效命中",str(data.successful_clicks)],["点击准确率",accuracy],["每秒有效命中","%.2f" % (float(data.successful_clicks)/maxf(game.elapsed,0.001))],["命中间隔 · 中位数",percentile(data.intervals_ms,0.5)],["命中间隔 · 90%分位",percentile(data.intervals_ms,0.9)],["总点击 / 空枪","%d / %d" % [game.shots,game.shots-game.hits]]]
		notes = "命中间隔是两次成功点击之间的时间，包含选靶与移动，不能直接称为反应时间。\n优先保持准确率，再观察有效命中频率；本关使用原始命中量，不套用 Aim Lab 内部评分。"
	elif game.level.mode == 20:
		cards = [["完成分区","%d / 3" % data.completed_bays.size()],["最大连续暴露","%.2f s" % data.max_exposure_seconds],["平均连续暴露","%.2f s" % data.mean_exposure_seconds],["探出 / 危险探出","%d / %d" % [data.exposure_count,data.dangerous_exposures]],["每次探出有效命中","%.2f" % data.hits_per_exposure],["射击命中率",accuracy]]
		notes = (data.failure_reason if not data.failure_reason.is_empty() else "三个交火区已完成") + "\n任意敌人连续看见你达到1秒即失败；完整缩回遮挡后清零。F5重开训练。"
	elif game.level.mode in [1,2]:
		cards = [["准心在靶",ratio(data.on_target_seconds,game.level.visible_seconds)],["子弹命中率",accuracy],["最长连续在靶","%.2f s" % data.longest_tracking_seconds],["变向重获 · 中位数",percentile(data.reacquisition_ms,0.5)],["变向 / 尚未重获","%d / %d" % [data.reversal_count,data.unresolved_reversals]],["中心角误差 · RMS","%.2f°" % data.rms_angular_error_deg]]
		notes = "准心覆盖和子弹命中是两项数据：换弹也持续统计瞄准，后坐力会影响实际射击。\n重获时间从目标真实反向到再次在靶计算；未重获的变向单独保留，避免只统计成功样本。"
	elif game.level.mode == 3:
		cards = [["机会 / 命中机会","%d / %d" % [data.opportunities,data.successful_trials]],["已完成穿越 / 漏打","%d / %d" % [data.completed_crossings,data.missed_crossings]],["首发延迟 · 中位数",percentile(data.reaction_ms,0.5)],["暴露时长 · 中位数",percentile(data.exposure_windows_ms,0.5)],["空窗开火",str(data.false_starts)],["射击命中率",accuracy]]
		notes = "首发延迟从首次可见到暴露期间首次射击计算，包含射空；本轮结束时尚未完成的穿越不计漏打。\n先用 F9 加宽门缝或减速；本轮调节过程写入成绩记录，改参数后的成绩不能直接混比。"
	elif game.level.mode == 4:
		cards = [["正确优先靶",str(data.switch_latencies_ms.size())],["误打其他靶",str(data.wrong_target_hits)],["转移耗时 · 中位数",percentile(data.switch_latencies_ms,0.5)],["转移耗时 · 90%分位",percentile(data.switch_latencies_ms,0.9)],["子弹命中率",accuracy],["射击次数",str(game.shots)]]
		notes = "转移耗时从新优先标记出现到该靶击中，包含换弹与操作停顿。\n先确认顺序正确，再缩短瞄准和制动时间；误打其他靶不计入正确优先靶。"
		if data.required_zone == "head":
			cards[4] = ["非头部命中",str(data.invalid_zone_hits)]
			notes = "只有优先目标的头部命中才计入有效转移；误打其他靶和非头部命中分别记录。\n转移耗时包含换弹与操作停顿，先保持动作完整，再逐步加速。"
		if data.alternating_strafe:
			cards[5] = ["脚步未满足",str(data.invalid_strafe_hits)]
			notes += " 每次有效命中需在地面向相反方向横移。"
	elif game.level.mode == 5:
		cards = [["完整动作",str(data.movement_successes)],["呈现目标",str(data.movement_opportunities)],["无效动作命中",str(data.movement_invalid_hits)],["停稳开火占比",ratio(data.stopped_shots,data.shot_speeds.size())],["真实命中率",accuracy],["射击次数",str(game.shots)]]
		notes = "完整动作需要瞄过、横移和停稳爆头，单独的命中不会替代这些条件。呈现数包含结束时的当前目标。\n先分解动作再连贯完成；共享玩家的制动方式与 Valorant 引擎并不相同。"
		if data.movement_variant == 1:
			notes = notes.replace("瞄过、横移","瞄不足、同向横移")
	else:
		var errors: Array = []
		for seen in data.clearance_first_seen.values():
			errors.append(float(seen.angular_error_deg))
		errors.sort()
		var error_text: String = "—" if errors.is_empty() else "%.2f°" % errors[floori(errors.size()/2.0)]
		cards = [["清除目标","%d / 3" % game.kills],["用时","%.2f s" % game.elapsed],["首见瞄准误差 · 中位数",error_text],["首见到击倒 · 中位数",percentile(data.clearance_hit_delays_ms,0.5)],["最多同时暴露靶",str(data.maximum_visible_targets)],["多角暴露时长","%.2f s" % data.multiple_exposure_seconds]]
		notes = "首见误差检查目标第一次进入视野时，准心离头部有多远；多角暴露按真实掩体视线判断。\n成绩是本训练场的反馈；走近目标或记住固定位置，也可能改善数字，应结合路线复盘。"
	for i in 6:
		get_node("Panel/Card%d/Label" % i).text = cards[i][0]
		get_node("Panel/Card%d/Value" % i).text = cards[i][1]
	$Panel/Notes.text = notes
	var history: Variant = JSON.parse_string(FileAccess.get_file_as_string(game.get_node("Companion").history_path())) if FileAccess.file_exists(game.get_node("Companion").history_path()) else []
	$Panel/Comparison.text = preload("res://scripts/training/training_comparison.gd").summary(history if history is Array else [],data,game.level_index+1,game.elapsed)
	$Panel.show()

func _process(_delta: float) -> void:
	if not $Panel.visible:
		return
	var size: Vector2 = get_viewport().get_visible_rect().size
	$Panel.scale = Vector2.ONE * minf(size.x/1600.0,size.y/900.0)
	$Panel.position = (size-Vector2(1280,740)*$Panel.scale)/2.0
