extends VBoxContainer

var cia_values = {
	"C": 100.0,
	"I": 100.0,
	"A": 100.0
}

@onready var title_label = $Title
@onready var confidentiality_bar = $ConfidentialityContainer/Bar
@onready var integrity_bar = $IntegrityContainer/Bar
@onready var availability_bar = $AvailabilityContainer/Bar

func _ready():
	update_display()

func reduce_cia(cia_type: String, amount: float):
	if cia_values.has(cia_type):
		cia_values[cia_type] = max(0, cia_values[cia_type] - amount)
		update_display()
		show_damage_effect(cia_type)

func update_display():
	confidentiality_bar.value = cia_values["C"]
	integrity_bar.value = cia_values["I"]
	availability_bar.value = cia_values["A"]
	
	# Update fill colors
	update_bar_fill_color(confidentiality_bar, cia_values["C"])
	update_bar_fill_color(integrity_bar, cia_values["I"])
	update_bar_fill_color(availability_bar, cia_values["A"])
	
	# Update title
	var avg = (cia_values["C"] + cia_values["I"] + cia_values["A"]) / 3.0
	title_label.text = "🖥️ SYSTEM HEALTH: %d%%" % int(avg)
	
	if avg < 30:
		title_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	elif avg < 60:
		title_label.add_theme_color_override("font_color", Color(1, 1, 0.2))
	else:
		title_label.add_theme_color_override("font_color", Color(1, 1, 1))

func update_bar_fill_color(bar: ProgressBar, value: float):
	var style = bar.get_theme_stylebox("fill")
	if style is StyleBoxFlat:
		if value < 30:
			style.bg_color = Color(1, 0.2, 0.2, 0.73)  # Red with transparency
		elif value < 60:
			style.bg_color = Color(1, 0.6, 0, 0.73)  # Orange with transparency
		else:
			style.bg_color = Color(0, 0.725, 0.412, 0.73)  # Green with transparency (#00b9419a)

func show_damage_effect(cia_type: String):
	var bar = get_bar_for_type(cia_type)
	if bar:
		var original_scale = bar.scale
		var tween = create_tween()
		tween.tween_property(bar, "scale", original_scale * 1.1, 0.1)
		tween.tween_property(bar, "scale", original_scale, 0.1)

func get_bar_for_type(cia_type: String) -> ProgressBar:
	match cia_type:
		"C": return confidentiality_bar
		"I": return integrity_bar
		"A": return availability_bar
	return null

func is_system_critical() -> bool:
	return cia_values["C"] <= 0 or cia_values["I"] <= 0 or cia_values["A"] <= 0