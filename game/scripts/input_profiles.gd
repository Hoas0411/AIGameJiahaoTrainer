extends Window

signal selected_profile(data: Dictionary)
var profiles: Array = []
var current_id: String = "custom"



# 保存转换网站返回的原始厘米数，每个预设有完整查询 URL 可复核。
func _ready() -> void:
	profiles = JSON.parse_string(FileAccess.get_file_as_string("res://resources/input_profiles.json"))
	close_requested.connect(hide)
	$Close.pressed.connect(hide)
	$Source.pressed.connect(func(): OS.shell_open("https://www.mouse-sensitivity.com/n/cs2-to-delta-force/"))
	for index in range(profiles.size()):
		get_node("Select" + str(index)).pressed.connect(func(): apply_profile(index))
		get_node("Value" + str(index)).text = "%.4f cm / 360°\n有效 yaw %.12f° / count / 灵敏度" % [profiles[index].cm360, profiles[index].yaw]



# 用户主动选择才覆盖输入设置；三种启动脚本也走同一入口。
func apply_profile(index: int) -> void:
	if index < 0 or index >= profiles.size():
		return
	current_id = profiles[index].id
	selected_profile.emit(profiles[index])
	$Status.text = "已应用方案 " + current_id.to_upper() + "。腰射依据为网站数据；瞄准采用屏幕距离公式，仍需本体实测确认。"



# 支持 A、B、C 三个独立启动入口，并保留切换前的个人配置备份。
func apply_launch_argument() -> void:
	for argument in OS.get_cmdline_user_args():
		for index in range(profiles.size()):
			if argument == "--input-profile=" + profiles[index].id:
				apply_profile(index)
