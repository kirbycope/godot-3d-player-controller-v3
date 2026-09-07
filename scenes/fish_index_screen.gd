class_name FishIndexScreen
extends PlayerMenuLayer
## Every species that can be caught, from the pause menu. A species you have landed shows its name, its record
## length and the conditions it bites in, read from its [Fish] resource; one you have not is a dark shape and a
## row of question marks, with the conditions still listed so you know what to try.

@export var species: Array[Fish] = [] ## The species listed, in this order.
@export var placeholder_model: PackedScene ## Model for species without a [member Item.model_scene] of their own.

var shown: Fish
var buttons: Array[Button] = []

@onready var list: VBoxContainer = %List
@onready var model_pivot: Node3D = %ModelPivot
@onready var model_camera: Camera3D = %ModelCamera
@onready var name_label: Label = %NameLabel
@onready var conditions_label: Label = %ConditionsLabel
@onready var record_label: Label = %RecordLabel
@onready var back_button: Button = %Back


func _ready() -> void:
	super()
	for fish: Fish in species:
		var button: Button = Button.new()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_show.bind(fish))
		button.focus_entered.connect(_show.bind(fish))
		list.add_child(button)
		buttons.append(button)
	if not buttons.is_empty():
		focus_on_show = buttons[0]
	back_button.pressed.connect(hide_menu)
	set_process(false)


func _input(event: InputEvent) -> void:
	super(event)
	if visible and event.is_action_pressed("ui_cancel"):
		hide_menu()
		get_viewport().set_input_as_handled()


func show_menu() -> void:
	refresh()
	super()
	set_process(true)


func hide_menu() -> void:
	super()
	set_process(false)


func _process(delta: float) -> void:
	model_pivot.rotate_y(delta * 0.8)


## Renames every row for what the log says has been caught.
func refresh() -> void:
	for i: int in buttons.size():
		buttons[i].text = species[i].get_display_name() if _has_caught(species[i]) else "???"
	if not species.is_empty():
		_show(shown if shown else species[0])


func _has_caught(fish: Fish) -> bool:
	var log: FishingLog = _log()
	return log != null and log.has_caught(fish)


func _log() -> FishingLog:
	return player.get_node_or_null(^"FishingLog") as FishingLog if player else null


## Fills the right-hand panel for [param fish].
func _show(fish: Fish) -> void:
	shown = fish
	var caught: bool = _has_caught(fish)
	name_label.text = fish.get_display_name() if caught else "???"
	conditions_label.text = "\n".join(fish.describe_conditions())
	var log: FishingLog = _log()
	record_label.text = "Record: %.1f cm" % log.record_of(fish) if caught and not fish.is_junk else ("Found" if caught else "Not yet caught")
	for child: Node in model_pivot.get_children():
		child.queue_free()
	var scene: PackedScene = fish.get_model_scene() if fish.get_model_scene() else placeholder_model
	if scene == null:
		return
	var model: Node3D = scene.instantiate() as Node3D
	model_pivot.add_child(model)
	fish.prepare_model(model) # once in the tree, so the model's own ready nodes exist
	var shadow: StandardMaterial3D = StandardMaterial3D.new()
	shadow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow.albedo_color = Color(0.05, 0.05, 0.08)
	var bounds: AABB = AABB()
	var first: bool = true
	for geometry: Node in model.find_children("*", "GeometryInstance3D", true, false):
		var visual: GeometryInstance3D = geometry as GeometryInstance3D
		if not caught:
			visual.material_override = shadow # a dark shape until you have landed one
		var box: AABB = (model_pivot.global_transform.affine_inverse() * visual.global_transform) * visual.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	if not first:
		model.position = -bounds.get_center()
		model_camera.size = maxf(bounds.get_longest_axis_size() * 1.4, 0.1)
