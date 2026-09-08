class_name FishCaughtScreen
extends PlayerMenuLayer
## The catch held up, Zelda style: the fish turning in front of a fan of rays (`resources/shaders/radial_shine.gdshader`),
## its name, its length with a star when it is the record, and its flavour text ([member Item.description]). A
## [PlayerMenuLayer], so the Player stands still and, alone, the world pauses; Action, Confirm, Cancel or Start puts it
## away. The rod on the Player opens it once the catch has arced into their hands; junk reads "Junk" for its size.

@export var placeholder_model: PackedScene ## Model for a species without a [member Item.model_scene] of its own.

var shown: Fish

@onready var model_pivot: Node3D = %ModelPivot
@onready var model_camera: Camera3D = %ModelCamera
@onready var preview: SubViewportContainer = %Preview
@onready var icon: TextureRect = %Icon
@onready var name_label: Label = %NameLabel
@onready var size_label: Label = %SizeLabel
@onready var flavor_label: Label = %FlavorLabel


func _ready() -> void:
	super()
	set_process(false)


func _input(event: InputEvent) -> void:
	super(event)
	if visible and (event.is_action_pressed("action") or event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel")):
		hide_menu()
		get_viewport().set_input_as_handled()


## Fills the screen for [param fish] at [param length_cm] and shows it; [param is_record] adds the star.
func show_catch(fish: Fish, length_cm: float, is_record: bool = false) -> void:
	shown = fish
	name_label.text = fish.get_display_name()
	size_label.text = "Junk" if fish.is_junk else "%.1f cm%s" % [length_cm, "  * record" if is_record else ""]
	flavor_label.text = fish.description
	_show_model(fish)
	show_menu()


func show_menu() -> void:
	super()
	set_process(true)


func hide_menu() -> void:
	super()
	set_process(false)


func _process(delta: float) -> void:
	model_pivot.rotate_y(delta * 0.8)


## The species' model turning in the viewport, at its base size and centred as the inventory preview does; the icon
## stands in when there is no model at all.
func _show_model(fish: Fish) -> void:
	for child: Node in model_pivot.get_children():
		child.queue_free()
	var scene: PackedScene = fish.get_model_scene() if fish.get_model_scene() else placeholder_model
	preview.visible = scene != null
	icon.visible = scene == null
	if scene == null:
		icon.texture = fish.icon
		icon.modulate = fish.get_icon_color()
		return
	var model: Node3D = scene.instantiate() as Node3D
	model_pivot.add_child(model)
	fish.prepare_model(model) # once in the tree, so the model's own ready nodes exist
	var bounds: AABB = AABB()
	var first: bool = true
	for geometry: Node in model.find_children("*", "GeometryInstance3D", true, false):
		var visual: GeometryInstance3D = geometry as GeometryInstance3D
		var box: AABB = (model_pivot.global_transform.affine_inverse() * visual.global_transform) * visual.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	if not first:
		model.position = -bounds.get_center()
		model_camera.size = maxf(bounds.get_longest_axis_size() * 1.4, 0.1)
