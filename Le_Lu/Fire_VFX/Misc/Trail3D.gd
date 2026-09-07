@tool
class_name FireVfxTrail3D extends MeshInstance3D # Renamed: Godot 4.8 added a native Trail3D

enum InterpolationMode {
	LINEAR,
	SQUARE,
	CUBE,
	QUAD
}
enum InterpolationDirection {
	FORWARD,
	BACKWARD
}

var points  = []
var widths  = []
var lifePoints = []

@export var trailEnabled = true

@export var fromWidth = 0.5
@export var toWidth = 0.0
@export_range(0.5, 1.5) var scaleAcceleration:float  = 1.0

@export var motionDelta = 0.1
@export var lifespan = 1.0

@export var scaleTexture = true
@export var startColor = Color(1.0, 1.0, 1.0, 1.0)
@export var endColor = Color(1.0, 1.0, 1.0, 0.0)

@export var colorInterpolationMode = InterpolationMode.LINEAR
@export var interpolationDirection = InterpolationDirection.FORWARD

var oldPos

func _ready():
	oldPos = get_global_transform().origin
	mesh = ImmediateMesh.new()

func _process(delta):
	
	if (oldPos - get_global_transform().origin).length() > motionDelta and trailEnabled:
		appendPoint()
		oldPos = get_global_transform().origin
	
	# Update life points
	for i in range(points.size()):
		lifePoints[i] += delta
	
	# Don't remove points immediately when they expire
	# Instead, we'll handle the fading in the rendering
	
	mesh.clear_surfaces()
	
	if points.size() < 2:
		return
	
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)

	for i in range(points.size()):
		var t = float(i) / (points.size() - 1.0)
		
		var currColor = endColor
		var progress = t

		if interpolationDirection == InterpolationDirection.BACKWARD:
			progress = 1 - t

		# Calculate base color interpolation
		if colorInterpolationMode == InterpolationMode.LINEAR:
			currColor = startColor.lerp(endColor, 1 - progress)
		elif colorInterpolationMode == InterpolationMode.SQUARE:
			currColor = startColor.lerp(endColor, 1 - (progress ** 2))
		elif colorInterpolationMode == InterpolationMode.CUBE:
			currColor = startColor.lerp(endColor, 1 - pow(progress, 3))
		elif colorInterpolationMode == InterpolationMode.QUAD:
			currColor = startColor.lerp(endColor, 1 - pow(progress, 4))

		# Apply lifetime-based fade at the beginning of the trail
		# This makes old points fade out without moving vertices
		var lifeProgress = lifePoints[i] / lifespan
		if lifeProgress >= 1.0:
			# Point has expired, make it completely transparent
			currColor.a = 0.0
		else:
			# Apply gradual fade as point ages
			var fadeAmount = smoothstep(0.0, 1.0, lifeProgress)
			currColor.a *= (1.0 - fadeAmount)

		mesh.surface_set_color(currColor)
		
		var currWidth = widths[i][0] - pow(1 - t, scaleAcceleration) * widths[i][1]
		
		if scaleTexture:
			var t0 = motionDelta * i
			var t1 = motionDelta * (i + 1)
			mesh.surface_set_uv(Vector2(t0, 0))
			mesh.surface_add_vertex(to_local(points[i] + currWidth))
			mesh.surface_set_uv(Vector2(t1, 1))
			mesh.surface_add_vertex(to_local(points[i] - currWidth))
		else:
			var t0 = i / points.size()
			var t1 = t
			
			mesh.surface_set_uv(Vector2(t0, 0))
			mesh.surface_add_vertex(to_local(points[i] + currWidth))
			mesh.surface_set_uv(Vector2(t1, 1))
			mesh.surface_add_vertex(to_local(points[i] - currWidth))
	
	mesh.surface_end()
	
	# Clean up points that are completely faded out
	# Only remove points from the beginning if they're older than lifespan + a small buffer
	# This ensures the trail doesn't contract suddenly
	while points.size() > 0 and lifePoints[0] > lifespan * 1.1:
		removePoint(0)

func appendPoint():
	var direction = get_global_transform().origin - oldPos
	direction = direction.normalized()
	rotation.y = atan2(direction.x, direction.z)
	
	points.append(get_global_transform().origin)
	widths.append([
		get_global_transform().basis.x * fromWidth,
		get_global_transform().basis.x * fromWidth - get_global_transform().basis.x * toWidth])
	lifePoints.append(0.0)
	
func removePoint(i):
	points.remove_at(i)
	widths.remove_at(i)
	lifePoints.remove_at(i)
