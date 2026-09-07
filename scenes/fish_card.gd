class_name FishCard
extends PanelContainer
## Catch card on the HUD: a colour swatch, the item's name and a line of detail, shown for a few seconds.

@onready var swatch: ColorRect = %Swatch
@onready var name_label: Label = %NameLabel
@onready var detail_label: Label = %DetailLabel
@onready var hide_timer: Timer = $HideTimer ## Hides the card; its timeout is wired to [method hide] in the scene.


## A landed fish; [param is_record] marks the biggest of its kind so far.
func show_catch(fish: Fish, length_cm: float, is_record: bool = false) -> void:
	var detail: String = "Junk" if fish.is_junk else "%.1f cm" % length_cm
	if is_record:
		detail += "  * record"
	show_item(fish, detail)


## Any item with a line under it: chum from a shot fish, say.
func show_item(item: Item, detail: String) -> void:
	swatch.color = item.get_icon_color()
	name_label.text = item.get_display_name()
	detail_label.text = detail
	pivot_offset = size * 0.5
	scale = Vector2(0.6, 0.6)
	show()
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	hide_timer.start()
