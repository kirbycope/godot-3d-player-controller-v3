extends Node3D

@export_file("*.tscn") var single_player_scene: String
@export_file("*.tscn") var multi_player_scene: String

@onready var title_screen: CanvasLayer = $TitleScreen
@onready var loading: Loading = $Loading


func single_player() -> void:
	loading.load_scene(single_player_scene)


func multi_player() -> void:
	loading.load_scene(multi_player_scene)
