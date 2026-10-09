extends RefCounted
## Pure decision policy. No scoring, player controls, AI requests or scene writes.
const CRYING := 1
const HAPPY := 2
const EXCITED := 3
const SMUG := 4
const ANGRY := 5
const SCARED := 6
var recent: Array[bool] = []
var streak := 0
var next_comment := 0.0
var last_hurt := -100.0
var hurt_count := 0

func reset() -> void:
	recent.clear()
	streak = 0
	next_comment = 0
	last_hurt = -100
	hurt_count = 0

func response(face: int, text: String, priority: int = 1) -> Dictionary:
	return {"face":face, "text":text, "priority":priority, "duration":4.0}

func shot(hit: bool, now: float) -> Dictionary:
	recent.append(hit)
	if recent.size() > 12: recent.pop_front()
	streak = streak + 1 if hit else 0
	if now < next_comment: return {}
	if streak >= 10:
		next_comment = now + 14
		return response(SCARED, "一枪都不空……你别把准星转向我呀！")
	if recent.size() >= 8 and recent.count(true) <= recent.size() / 4 and not hit:
		next_comment = now + 14
		return response(SMUG, "嘿嘿，你是在给空气做按摩嘛？慢慢瞄，我等你～")
	return {}

func fast_reaction(milliseconds: float, now: float) -> Dictionary:
	# Reject anticipation / invalid samples, not just long delays.
	if milliseconds < 100 or milliseconds > 230 or now < next_comment: return {}
	next_comment = now + 12
	return response(EXCITED, "哇！这么快就反应过来啦！再来一次！")

func hurt(now: float) -> Dictionary:
	hurt_count = hurt_count + 1 if now - last_hurt < 8 else 1
	last_hurt = now
	next_comment = now + 10
	if hurt_count >= 3:
		return response(ANGRY, "喂！唔准再打我啦！", 3)
	if hurt_count == 2:
		return response(SCARED, "唔好再打啦……我惊呀！", 3)
	return response(CRYING, "你打我做乜嘢？", 3)

func hug(now: float) -> Dictionary:
	next_comment = now + 8
	hurt_count = 0
	return response(HAPPY, "嘿咻～抱稳我呀！", 4)
