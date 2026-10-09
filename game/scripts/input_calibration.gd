extends Window

signal calibrated(yaw: float)
var parameters: Array[float] = []



# 原生 HTTPRequest 只查询公开腰射转换接口，不需要登录。
func _ready() -> void:
	close_requested.connect(hide)
	$Calculate.pressed.connect(calculate)
	$Request.request_completed.connect(received)



# 冻结此次计算的输入；弹窗期间不允许修改后面的设置。
func configure(sens: float, dpi: float, fov: float, md: float, horizontal: float) -> void:
	parameters = [sens, dpi, fov, md, horizontal]
	$Status.text = "鼠标灵敏度 %.2f / DPI %.0f / 水平 %.2f / FOV %.0f / 屏幕距离 %.2f\n请确认这些值和三角洲本体相同。\n更改 FOV 或屏幕距离系数后，请重新计算。\n本功能校准腰射；镭射和倍镜仍需要独立实测。" % [sens, dpi, horizontal, fov, md]



# 以三角洲为来源转换至 CS2，仅取不依赖输出灵敏度舍入的 cm/360。
func calculate() -> void:
	$Calculate.disabled = true
	var q := "https://www.mouse-sensitivity.com/edpi/?query=calculate&aimid1=7350&aimid2=4602&dpi1=%s&dpi2=800&sens1-1=%s&sens2-1=%s&multi1-1=%s&multi2-1=null&sens1-2=1&sens2-2=null&multi1-2=null&multi2-2=null&fov1=%s&fov2=90&hres1=1920&vres1=1080&hres2=1920&vres2=1080" % [parameters[1], parameters[4], parameters[3], parameters[0], parameters[2]]
	$Status.text = "正在查询 Mouse-Sensitivity.com…"
	if $Request.request(q, ["User-Agent: Mozilla/5.0"]) != OK:
		$Calculate.disabled = false
		$Status.text = "无法连接，已保留原设置。"



# 只有合法成功响应才应用换算值，网络失败不会改动现有灵敏度。
func received(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	$Calculate.disabled = false
	var data = JSON.parse_string(body.get_string_from_utf8())
	if result != HTTPRequest.RESULT_SUCCESS or code != 200 or not data is Dictionary or not data.has("cm") or not (data.cm is float or data.cm is int) or data.cm <= 0:
		$Status.text = "转换服务不可用，原设置未改变。可使用本体实测导入。"
		return
	var yaw: float = 914.4 / (parameters[1] * parameters[0] * parameters[4] * data.cm)
	calibrated.emit(yaw)
	var file := FileAccess.open("user://converter_last_result.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"parameters": parameters, "response": data, "yaw": yaw, "source": "mouse-sensitivity.com", "time": Time.get_datetime_string_from_system()}))
	$Status.text = "已应用：%.4f cm / 360°\n换算系数 %.10f\n来源：Mouse-Sensitivity.com 腰射转换\n这是第三方转换结果，仍请在本体核对一圈距离。" % [data.cm, yaw]
