extends RefCounted

static func populate(container: VBoxContainer, conversation: Array, busy: bool) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
	container.add_theme_constant_override("separation", 22)
	var entries := conversation.duplicate()
	if entries.is_empty():
		entries.append({"role":"assistant", "content":"今天过得怎么样？想聊训练，还是先聊聊今天的事？", "source":"fallback"})
	for entry in entries:
		var mine: bool = entry.get("role", "") == "user"
		var row := VBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 8)
		container.add_child(row)
		var identity := Label.new()
		identity.text = "你" if mine else "麦小鼠  ·  " + ("AI" if entry.get("source", "") == "ai" else "本地陪伴")
		if not mine and int(entry.get("latency_ms", 0)) > 0:
			identity.text += "  ·  本次回复 %.2f 秒" % (float(entry.latency_ms) / 1000.0)
		identity.add_theme_font_size_override("font_size", 15)
		identity.add_theme_color_override("font_color", Color("c1c4ca"))
		identity.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if mine else HORIZONTAL_ALIGNMENT_LEFT
		row.add_child(identity)
		var aligner := HBoxContainer.new()
		aligner.alignment = BoxContainer.ALIGNMENT_END if mine else BoxContainer.ALIGNMENT_BEGIN
		row.add_child(aligner)
		var panel := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color("303237") if mine else Color("26272b")
		style.set_corner_radius_all(18)
		style.content_margin_left = 16
		style.content_margin_right = 16
		style.content_margin_top = 12
		style.content_margin_bottom = 12
		panel.add_theme_stylebox_override("panel", style)
		aligner.add_child(panel)
		var body := RichTextLabel.new()
		body.bbcode_enabled = false
		body.fit_content = true
		body.scroll_active = false
		body.selection_enabled = true
		body.add_theme_font_size_override("normal_font_size", 20)
		body.add_theme_constant_override("line_separation", 5)
		body.add_theme_color_override("default_color", Color("e1e2e5"))
		var text: String = str(entry.get("content", ""))
		var font: Font = container.get_theme_default_font()
		var measured := font.get_string_size(text.get_slice("\n", 0), HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		body.custom_minimum_size.x = clampf(measured + 5, 180, 670 if not mine else 560)
		body.text = text
		panel.add_child(body)
	if busy:
		var waiting := Label.new()
		waiting.text = "麦小鼠正在回复…"
		waiting.add_theme_font_size_override("font_size", 16)
		waiting.add_theme_color_override("font_color", Color("43d1d6"))
		container.add_child(waiting)
