@tool
extends EditorPlugin
## GARP registers nothing at enable time: [Inventory], [InventoryScreen], [ItemPickup], [Item] and the save
## resources carry class_name and icons of their own. Enabling the plugin lists it in Project Settings.


func _enter_tree() -> void:
	pass


func _exit_tree() -> void:
	pass
