class_name FishCard
extends PanelContainer
## Catch card on the HUD: a colour swatch, the fish's name and its length, shown for a few seconds.

@onready var swatch: ColorRect = %Swatch
@onready var name_label: Label = %NameLabel
@onready var detail_label: Label = %DetailLabel
@onready var hide_timer: Timer = $HideTimer ## Hides the card; its timeout is wired to [method hide] in the scene.


func show_catch(fish: Fish, length_cm: float) -> void:
	swatch.color = fish.color
	name_label.text = fish.display_name
	detail_label.text = "Junk" if fish.is_junk else "%.1f cm" % length_cm
	pivot_offset = size * 0.5
	scale = Vector2(0.6, 0.6)
	show()
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	hide_timer.start()
