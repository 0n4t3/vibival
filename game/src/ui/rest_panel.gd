extends Control
## How long to rest in a bed: a slider from a quarter of an hour to two days.

signal chosen(hours: float)
signal cancelled

const MIN_HOURS := 0.25
const MAX_HOURS := 48.0

var slider: HSlider
var _amount: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.45)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(380, 0)
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	var title := Label.new()
	title.text = "Rest in bed"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	box.add_child(title)
	_amount = Label.new()
	_amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_amount.add_theme_font_size_override("font_size", 18)
	box.add_child(_amount)
	slider = HSlider.new()
	slider.min_value = MIN_HOURS
	slider.max_value = MAX_HOURS
	slider.step = 0.25
	slider.custom_minimum_size = Vector2(0, 34)
	slider.value_changed.connect(func(_v): _show())
	box.add_child(slider)
	var quick := HBoxContainer.new()
	quick.alignment = BoxContainer.ALIGNMENT_CENTER
	quick.add_theme_constant_override("separation", 8)
	box.add_child(quick)
	for h in [1, 4, 8, 12, 24]:
		var b := Button.new()
		b.text = "%d h" % h
		b.custom_minimum_size = Vector2(58, 36)
		b.pressed.connect(func(): slider.value = h)
		quick.add_child(b)
	var note := Label.new()
	note.text = "Hunger or thirst will wake you early."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.modulate = Color(1, 1, 1, 0.7)
	box.add_child(note)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	var rest := Button.new()
	rest.text = "Rest"
	rest.custom_minimum_size = Vector2(130, 42)
	rest.pressed.connect(func(): chosen.emit(float(slider.value)))
	row.add_child(rest)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.custom_minimum_size = Vector2(130, 42)
	cancel.pressed.connect(func(): cancelled.emit())
	row.add_child(cancel)
	slider.value = 8.0
	_show()


static func describe(hours: float) -> String:
	var whole := int(hours)
	var mins := int(round((hours - whole) * 60.0))
	if whole == 0:
		return "%d minutes" % mins
	var h := "%d hour%s" % [whole, "" if whole == 1 else "s"]
	return h if mins == 0 else "%s %d minutes" % [h, mins]


func _show() -> void:
	_amount.text = describe(float(slider.value))


func open() -> void:
	visible = true
	slider.grab_focus()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		cancelled.emit()
