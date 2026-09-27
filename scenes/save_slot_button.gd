class_name SaveSlotButton
extends Button
## One save on the title screen's Continue list: its preview, its level, its number and when it was taken. Pressing
## it asks for that save, in its own level.

signal chosen(slot: int, scene_path: String) ## This save was picked.

@onready var preview: TextureRect = $HBoxContainer/Preview
@onready var level_label: Label = $HBoxContainer/VBoxContainer/Level
@onready var detail_label: Label = $HBoxContainer/VBoxContainer/Detail

var slot: int = 0
var scene_path: String = ""


## Fills the row from one of [method SaveGame.list_saves]'s entries.
func show_save(save: Dictionary) -> void:
	slot = int(save.get("slot", 0))
	scene_path = str(save.get("scene_path", ""))
	level_label.text = "Save %d: %s" % [slot, str(save.get("level_name", "Unknown"))]
	detail_label.text = _when(str(save.get("saved_at", "")))
	var picture: String = str(save.get("preview", ""))
	preview.texture = null
	if FileAccess.file_exists(picture):
		var image: Image = Image.load_from_file(ProjectSettings.globalize_path(picture))
		if image and not image.is_empty():
			preview.texture = ImageTexture.create_from_image(image)


## "2026-09-25T15:04:05" as "2026-09-25 15:04", in UTC as it was written.
static func _when(saved_at: String) -> String:
	if saved_at.is_empty():
		return ""
	return "Saved " + saved_at.replace("T", " ").left(16) + " UTC"


func _on_pressed() -> void:
	chosen.emit(slot, scene_path)
