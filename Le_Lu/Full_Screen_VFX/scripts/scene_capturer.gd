extends SubViewportContainer

var camera            :Camera3D
var fractured_glass   :Node3D
var mesh              :MeshInstance3D

var distance_to_glass :float = 2.0 

func _ready() -> void:
	camera          = $SubViewport/Camera3D
	fractured_glass = $SubViewport/sm_broken_screen
	mesh            = $SubViewport/sm_broken_screen/Armature/Skeleton3D/Glass_015
	
	match_screen_size() #maybe i should move this after screenshot thing..


func take_screenshot() -> void:
	var screen_img :Image      = get_tree().root.get_viewport().get_texture().get_image()
	var frozen_tex :Texture2D  = ImageTexture.create_from_image(screen_img)
	var _material   :Material   = mesh.material_override 
	
	if _material is StandardMaterial3D:
		_material.albedo_texture   = frozen_tex


# we need to do some trigonometry stuff to scale the plane to camera
func match_screen_size() -> void:
	var viewport_size   :Vector2 = get_viewport().get_visible_rect().size
	var aspect_ratio    :float   = viewport_size.x / viewport_size.y
	
	var fov_radians     :float   = deg_to_rad(camera.fov)
	
	var required_height :float = 2.0 * distance_to_glass * tan(fov_radians / 2.0)
	var required_width  :float = required_height * aspect_ratio
	
	# oops i've made the plane to 2x2.. need to fix
	var final_width     :float = required_width / 2.0
	var final_height    :float = required_height / 2.0
	
	fractured_glass.scale    = Vector3(final_width, final_height, 1.0)
	fractured_glass.position = camera.position + (camera.transform.basis.z * -distance_to_glass)


func do_break_screen_vfx_with_animation() -> void:
	take_screenshot()
	self.visible = true
	$SubViewport/sm_broken_screen/AnimationPlayer2.play("Init")
