class_name Bobber
extends Projectile
## A fishing float: flies on the rod's cast, floats on [Buoyancy] water and dips on nibbles and bites.
##
## It never sweeps for hits; its BuoyancyProbe child sits low so the float rides at the surface.

signal landed_in_water(water: Area3D) ## Emitted once when the float first enters a "WATER" area.
signal landed_dry ## Emitted when the float touches something before reaching water.

var in_water: bool = false

@onready var float_mesh: Node3D = $Float ## Holds both halves of the float so plunges move them together.


func _init() -> void:
	is_template = false
	lifetime = 600.0


func _physics_process(_delta: float) -> void:
	pass # No swept hits; the float only flies and floats.


## Wired to body_entered: ground before water means a bad cast. The caster's own body never counts.
func _on_body_entered(body: Node) -> void:
	if not in_water and body != shooter:
		landed_dry.emit()


## Wired to the WaterSensor's area_entered.
func _on_water_sensor_area_entered(area: Area3D) -> void:
	if in_water or not area.is_in_group("WATER"):
		return
	in_water = true
	landed_in_water.emit(area)


## Dips the float [param depth] metres and lets it bob back over [param duration] seconds.
func plunge(depth: float, duration: float) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(float_mesh, "position:y", -depth, duration * 0.3)
	tween.tween_property(float_mesh, "position:y", 0.0, duration * 0.7).set_trans(Tween.TRANS_BOUNCE)
