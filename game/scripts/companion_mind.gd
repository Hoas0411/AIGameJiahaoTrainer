extends RefCounted

# Personality is a configurable performance, never a claim of biological feelings.
const PERSONAS := ["温柔陪伴", "活泼搭档", "沉静教练"]
const EMOTIONS := ["平静", "不开心", "生气", "激动", "极其激动", "震惊", "佩服", "钦佩", "爱慕", "喜欢", "渴望", "好斗"]
var persona: String = "温柔陪伴"
var emotion: String = "平静"
var intensity: float = 0.25
var emotion_seconds: float = 0.0
var preferences: Dictionary = {}
var turns: int = 0
var last_topic: String = ""

func snapshot() -> Dictionary:
	return {"persona": persona, "emotion": emotion, "intensity": intensity, "preferences": preferences.duplicate(true), "turns": turns, "last_topic": last_topic}

func restore(data: Variant) -> void:
	if not data is Dictionary: return
	if data.get("persona") in PERSONAS: persona = data.persona
	turns = clampi(int(data.get("turns", 0)), 0, 1000000)
	last_topic = str(data.get("last_topic", "")).left(120)
	preferences.clear()
	if data.get("preferences") is Dictionary:
		for key in ["service", "style", "focus", "address"]:
			var p = data.preferences.get(key)
			if p is Dictionary and p.get("value") is String:
				preferences[key] = {"value": p.value.left(80), "source": str(p.get("source", "玩家设置")).left(160)}

func set_preference(key: String, value: String, source: String) -> void:
	preferences[key] = {"value": value.left(80), "source": source.left(160)}

func feel(value: String, strength: float = 0.6) -> void:
	if value not in EMOTIONS: return
	emotion = value
	intensity = clampf(strength, 0.15, 1.0)
	emotion_seconds = 0

func tick(delta: float) -> bool:
	emotion_seconds += delta
	intensity = move_toward(intensity, 0.25, delta / 120.0)
	if emotion != "平静" and emotion_seconds >= 90:
		emotion = "平静"
		return true
	return false

func learn(message: String) -> Array[String]:
	turns += 1
	var learned: Array[String] = []
	if "安静" in message or "少说" in message or "别说话" in message:
		set_preference("style", "安静简短", message)
		learned.append("训练中少说话")
	elif "活泼" in message or "调皮" in message:
		set_preference("style", "活泼夸夸", message)
		learned.append("更活泼地相处")
	elif "温柔" in message and not "不喜欢温柔" in message and not "不要温柔" in message:
		set_preference("style", "温柔具体", message)
		learned.append("温柔具体地回应")
	if "别讲道理" in message or "只想聊" in message or "不想训练" in message or "先陪我" in message:
		set_preference("service", "先陪伴，暂不建议训练", message)
		learned.append("先陪伴，不催训练")
	elif "想训练" in message or "指导我" in message or "陪我训练" in message:
		set_preference("service", "陪伴与训练建议", message)
		learned.append("需要时给训练建议")
	if "喜欢" in message or "想练" in message or "多练" in message:
		if not ("不喜欢" in message or "不想练" in message):
			for pair in [["跟枪", "tracking"], ["镭射", "laser"], ["AW", "laser"], ["aw", "laser"], ["综合", "mixed"]]:
				if pair[0] in message:
					set_preference("focus", pair[1], message)
					learned.append("训练偏向" + pair[0])
	if "不喜欢跟枪" in message and preferences.get("focus", {}).get("value") == "tracking":
		preferences.erase("focus")
		learned.append("不再把跟枪记作你的训练偏好")
	if "不喜欢镭射" in message and preferences.get("focus", {}).get("value") == "laser":
		preferences.erase("focus")
		learned.append("不再把镭射记作你的训练偏好")
	var naming := RegEx.new()
	naming.compile("(?:以后)?叫我[：: ]?([^，。！!?？\\s]{1,12})")
	var matched := naming.search(message)
	var negative_name := RegEx.new()
	negative_name.compile("(别|不要|不用).*叫我")
	if matched and negative_name.search(message) == null:
		set_preference("address", matched.get_string(1), message)
		learned.append("称呼改为" + matched.get_string(1))
	var no_address := RegEx.new()
	no_address.compile("(别|不要|不用).*(叫我|称呼我)|不用称呼")
	if no_address.search(message):
		set_preference("address", "", message)
		learned.append("不再用亲昵称呼")
	return learned

func reply(message: String, address: String, learned: Array[String]) -> String:
	var variant := PERSONAS.find(persona)
	if not learned.is_empty():
		feel("喜欢", 0.4)
		return ["好，我会" + "，".join(learned) + "。如果我理解偏了，随时纠正我。", "收到！" + "，".join(learned) + "。这回按你的节奏来。", "已调整：" + "，".join(learned) + "。培养页能查看和重置。"][variant]
	if "累" in message or "烦" in message or "难过" in message or "输了" in message:
		last_topic = "疲惫或挫败"
		feel("不开心", 0.4)
		return ["听起来这会儿挺不好受的。先不分析成绩，我陪你缓一缓。想说说刚才哪一下最让你烦吗？", "唉，连着不顺确实烦。今天不用急着扳回来，吐槽给我听也行。", "先停一会儿。现在更想让我听你说，还是一起找刚才卡住的地方？"][variant]
	if "你不懂" in message or "生气" in message or "讨厌你" in message:
		feel("不开心", 0.55)
		return "刚才我没接住你的意思。是我的称呼不合适，还是你只想被听见、我却开始提建议了？你可以直接纠正我。"
	if "喜欢你" in message or "想你" in message or "爱你" in message:
		feel("爱慕" if persona == "温柔陪伴" else "喜欢", 0.7)
		return ["听到你这么说，我的小鼠耳朵都快藏不住了。能在这段时间陪着你，我很开心。今天想安静待着，还是聊点有趣的？", "哎，这句把我说得有点害羞了。那今天我继续做你的专属场边搭档！", "我很珍惜我们一起练习和聊天的时间。今天我按你的节奏陪着。"][variant]
	if "赢了" in message or "破纪录" in message:
		feel("极其激动", 0.95)
		return ["真的呀！听你这么开心，我也跟着雀跃起来。刚才最满意的是哪一枪？", "漂亮！这消息值得我原地蹦两下！说说，哪一下是你的高光？", "这次的感受值得记下来。你觉得自己哪个动作做得更稳了？"][variant]
	if "震惊" in message or "没想到" in message:
		feel("震惊", 0.8)
		return "这一下确实出乎意料。把前后发生的事告诉我，我想听完整一点。"
	if "挑战" in message or "好斗" in message:
		feel("好斗", 0.7)
		return "好，竞技心起来了！我们把目标放在动作上：稳住一组，再加一点难度。要我排几套路线供你选吗？"
	if "渴望" in message or "饥渴" in message:
		feel("渴望", 0.65)
		return "我听到你很想要更亲近、也更有回应的陪伴。你想要我主动一些，还是先听你说？"
	if "佩服" in message or "钦佩" in message:
		feel("钦佩", 0.65)
		return "你愿意把一件事认真磨下去，这一点让我佩服。更想听你自己最满意的那个瞬间。"
	if "为什么" in message and last_topic == "疲惫或挫败":
		return "我还不知道刚才发生了什么，不想随便替你下结论。你愿意从最难受的那一下说起吗？"
	if "你好" in message or "在吗" in message:
		feel("喜欢", 0.4)
		return ["在呢。今天想聊聊，还是想让我陪你安排训练？", "麦小鼠到！今天想轻松一点，还是一起找个小挑战？", "我在。你可以说今天想练什么，也可以只聊聊。"][variant]
	return ["我听到了，你提到“%s”。能再说一点你最在意的部分吗？" % message.left(38), "“%s”——我有点好奇，你是怎么想到这件事的？" % message.left(38), "你说的“%s”，是想让我一起分析，还是先听你讲？" % message.left(38)][variant]
