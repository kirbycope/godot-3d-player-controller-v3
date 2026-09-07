# GARP's contract with the 3D Player Controller

Everything GARP (`addons/garp`: scripts, scenes, resources, the editor panel and the tests in `tests/`) touches on
`addons/3d_player_controller`. The garp repo ships a stub package at the same paths that implements exactly this
surface, so `tests/` passes against the stub there and against the real addon in the player controller project.
`tests/integration/` needs the real addon and is not covered by this contract. Anything not listed here is not
GARP's to use; widen the table before widening the code.

## Player (`scripts/player.gd`, `class_name Player extends CharacterBody3D`)

| Member | Type | GARP needs it for |
|---|---|---|
| `controls` | `CanvasLayer` (a `Controls`) | `Inventory.rebuild_equipment_cache` calls `reset_labels()`; `InventoryScreen`, `SpellsScreen` and `RadialMenu` read `current_input_type`; `ActionPrompt` writes `joypad_button_0_label` |
| `crosshair` | `TextureRect` | `RadialMenu` hides it while the wheel is open and shows it after |
| `inventory` | `Inventory` | `ItemPickup.take`, `InventoryScreen.bind`, `SpellsScreen.bind`, `Equipment.equip`, the demo |
| `abilities` | `Abilities` | `Spellbook._apply` writes the wheel, `SpellsScreen.refresh` reads `active_ability` |
| `radial_menu` | `RadialMenu` (`$Inventory/RadialMenu`) | The tests reach the weapon wheel through it |
| `pause` | `PlayerMenuLayer` | The screens' Back button calls `pause.show_menu()` |
| `skeleton` | `Skeleton3D` | `Equipment.equip` adds a `BoneAttachment3D` under it; `Inventory.equip_from_backpack` reparents attachments onto it; `apply_save` checks it is there |
| `held_object` | `HeldObject` | `Inventory._unhandled_input` ignores weapon taps while `is_holding_object()` |
| `is_paused` | `bool` | `ItemPickup._input` ignores Action while paused; `PlayerMenuLayer.show_menu` / `hide_menu` set it |
| `is_riding` | `bool` | `ItemPickup` ignores a riding Player |
| `ready` | signal (Node) | `Spellbook._ready` waits for the Player before seeding the wheel |
| `get_facing_direction()` | `-> Vector3` | `Inventory._place_in_front` drops pickups a metre ahead (`Vector3.ZERO` falls back to forward) |
| `refresh_contextual_controls()` | `-> void` | `ActionPrompt.hide_for` gives the Action label back to the Player's state |
| `warp_to(target)` | `(Transform3D) -> void` | Tests move the Player onto and off dropped equipment |
| native | `is_multiplayer_authority()`, `up_direction`, `global_position`, `get_parent()`, `is_node_ready()` | `Inventory`, `ItemPickup`, `Spellbook` |

## Controls (`scripts/controls.gd`, `class_name Controls extends CanvasLayer`)

| Member | Type | GARP needs it for |
|---|---|---|
| `InputType` | enum `KEYBOARD_MOUSE, MICROSOFT, NINTENDO, SONY, TOUCH` | `current_input_type` values; `ActionPrompt` shows the child named after `InputType.keys()[type]` in PascalCase |
| `current_input_type` | `InputType` (default `TOUCH`) | `KEYBOARD_MOUSE` puts a held stack or spell under the mouse instead of the focused cell; the wheel reads the mouse or the right stick |
| `joypad_button_0_label` | `Label` | `ActionPrompt.show_for` writes "Pick Up" on the Action button |
| `reset_labels()` | `-> void` | Restores every label's scene text; called after the equipped set changes |
| InputMap actions | `action`, `start`, `ability`, `throw`, `last_weapon`, `next_weapon`, `look_up/down/left/right` | Registered in `_ready` when the project lacks them (the built in `ui_accept` and `ui_cancel` are used as they are) |

## HeldObject (`scripts/held_object.gd`, `class_name HeldObject extends Node`)

| Member | Type | GARP needs it for |
|---|---|---|
| `is_holding_object()` | `-> bool` | Weapon taps do nothing while an object is carried |

## PlayerMenuLayer (`scripts/player_menu_layer.gd`, `class_name PlayerMenuLayer extends CanvasLayer`)

`InventoryScreen` and `SpellsScreen` extend it.

| Member | Type | GARP needs it for |
|---|---|---|
| `player` | `@export Player` | The screens bind to `player.inventory`; `Pause` sets it on the screens it instances |
| `focus_on_show` | `@export Control` | Focused by `show_menu`; the screens leave it empty and focus a slot themselves |
| `_ready()` | | `set_process_input(is_multiplayer_authority())` then `fit_touch_buttons(self)` |
| `fit_touch_buttons(root)` | `static (Node) -> void` | Duplicates each `TouchScreenButton`'s `RectangleShape2D`, sizes it to the parent `Control` and centres it, now and on the control's `resized`; `InventorySlotButton` and `SpellNodeButton` call it on themselves |
| `_input(event)` | | `start` while visible calls `hide_menu()` and marks the event handled |
| `show_menu()` | `-> void` | Shows, sets `player.is_paused = true`, frees the mouse, focuses `focus_on_show` |
| `hide_menu()` | `-> void` | Hides, sets `player.is_paused = false`, captures the mouse |

## Pause (`scripts/pause.gd`, `extends PlayerMenuLayer`, scene `scenes/pause.tscn`)

| Member | Type | GARP needs it for |
|---|---|---|
| `inventory_screen_scene` | `@export_file String` | `player.tscn` points it at `res://addons/garp/scenes/inventory_screen.tscn`; empty hides the button |
| `spells_screen_scene` | `@export_file String` | Same for `res://addons/garp/scenes/spells_screen.tscn` |
| `inventory_screen`, `spells_screen` | `PlayerMenuLayer` | The instanced screens, added as siblings of Pause on the Player (deferred) with `player` set |
| `inventory_button`, `spells_button` | `Button` | Visible only when the matching scene path is set |
| `_on_inventory_pressed()`, `_on_spells_pressed()` | `-> void` | Hide Pause and `show_menu()` the screen |
| `_input(event)` | | `start` toggles the menu when the Player is not already paused by another screen |

## ActionPrompt (`scripts/action_prompt.gd`, `class_name ActionPrompt extends Node3D`, scene `scenes/action_prompt.tscn`)

`item_pickup.tscn` instances the scene as `ActionPrompt` and sets `message_end`.

| Member | Type | GARP needs it for |
|---|---|---|
| `message_end` | `@export String` | "to pick up" |
| `show_for(player, action_label)` | `(Player, String) -> void` | Shows the child for the Player's input type and writes `action_label` on `controls.joypad_button_0_label` |
| `hide_for(player)` | `(Player) -> void` | Hides and calls `player.refresh_contextual_controls()` |
| `update_text()` | `-> void` | Pushes `message_begin` / `message_end` into the labels; `ItemPickup` calls it before `show_for` |
| `visible` | `bool` | Tests check the prompt is up or down |

## Abilities (`scripts/abilities.gd`, `class_name Abilities extends CanvasLayer`)

| Member | Type | GARP needs it for |
|---|---|---|
| `player` | `@export Player` | `player.tscn` wires it |
| `abilities` | `@export Array[Ability]` | The wheel; `Spellbook._seed` reads the starting spells from it and `_apply` writes the loadout to it |
| `active_ability` | `@export Ability` | The first of `abilities` at ready; `Spellbook._apply` keeps it on the wheel; `SpellsScreen` marks the slot that holds it |

## Ability (`scripts/ability.gd`, `class_name Ability extends Resource`)

| Member | Type | GARP needs it for |
|---|---|---|
| `display_name` | `@export String` | Node buttons, details, wheel slots, palette labels, button names |
| `icon` | `@export Texture2D` | Node buttons, details, wheel slots, the held icon, the palette |
| `icon_color` | `@export Color` | Tints the icon everywhere it is drawn |
| `cooldown`, `cast_time`, `energy_cost` | `@export float` | Carried by `heal.tres` and `stealth.tres`; GARP saves the resources, not the fields |
| `cast_style` | `@export CastStyle` (`NONE, FORWARD, UPWARD, SWEEPING_SIDEWAYS, SWEEPING_UPWARD, POWER_UP`) | Set by both `.tres` files |
| `HealAbility` | `scripts/heal_ability.gd extends Ability` | `heal.tres` (`script_class="HealAbility"`); the editor's class chain test |
| `StealthAbility` | `scripts/stealth_ability.gd extends Ability` | `stealth.tres` (`script_class="StealthAbility"`); the editor's class chain test |

## Equipment (`scripts/equipment.gd`, `class_name Equipment extends Node3D`)

| Member | Type | GARP needs it for |
|---|---|---|
| `EquipmentType` | enum `AXE_1H, AXE_2H, BOW, DAGGER, FISHING_ROD, PISTOL, RIFLE, STAFF, SWORD_1H, SWORD_2H, SWORD_AND_SHIELD` | Order matters: `Inventory` sorts and looks up by it, `wooden_sword.tscn` stores `8` |
| `bone_attachment_bone_name` | `@export String` | Backpack conflicts, sorting, `equip` |
| `can_attack`, `can_shoot` | `@export bool` | `can_player_attack` / `can_player_shoot` |
| `can_log`, `can_mine` | `@export bool` | `has_equipment_with_capability(&"can_log")` reads them by name |
| `display_name`, `description` | `@export String` | Slot tooltips, the wheel, the details panel |
| `model_scene` | `@export PackedScene` | The details panel's turning preview |
| `equipment_type` | `@export EquipmentType` | Lookup and sorting |
| `icon` | `@export Texture2D` | Slots and the wheel |
| `is_exclusive` | `@export bool` | `stow_conflicting` |
| `position_offset`, `rotation_offset_degrees`, `scale_offset` | `@export Vector3` | `wooden_sword.tscn` sets them; `equip` applies them to the copy |
| `equipment_instance` | `Equipment` | `apply_save` collects the copies `equip` made |
| `player` | `Player` | Set on the equipped copy |
| `player_detection` | `Area3D` (`get_node_or_null("PlayerDetection")`) | The walk-over volume; `drop_equipment` listens to its `body_exited` |
| `get_details()` | `-> String` | Extra lines under the description |
| `equip(target_player)` | `(Player) -> bool` | Refuses without a bone, a duplicate on that bone or a full backpack; stows conflicts; makes a `BoneAttachment3D` on `player.skeleton` holding a duplicate with `scene_file_path` copied; `add_equipment` on the copy |
| `_on_player_detection_body_entered(body)` | `(Node3D) -> void` | Equips on the first authoritative Player unless the pickup's `dropped_by` meta is that Player, then stops monitoring |
| `scene_file_path` | native | `save`, `drop_equipment` and `_is_scene_path` |

## Files GARP loads by path

| Path | Used by |
|---|---|
| `scenes/player.tscn` | `demo.tscn`, every test; see the layout below |
| `scenes/action_prompt.tscn` | `item_pickup.tscn` |
| `scenes/pause.tscn` | `tests/integration/` |
| `scripts/equipment.gd` | `scenes/demo/wooden_sword.tscn` |
| `scripts/ability.gd` (`uid://klxo6bc3ftnp`) | `resources/spell_tree_demo.tres` typed array |
| `resources/abilities/heal.tres` (`uid://cfpp5cv2gcskg`) | `spell_tree_demo.tres`, `player.tscn`, tests |
| `resources/abilities/stealth.tres` (`uid://ywtv6gwnislu`) | `spell_tree_demo.tres`, `player.tscn`, tests |
| `assets/game_icons/gladius.svg` | `inventory_screen.tscn` tab, `wooden_sword.tscn`, `wooden_sword.tres` |
| `assets/game_icons/punch.svg` | `RadialMenu.PUNCH_ICON` |
| `assets/icons/heal.svg`, `assets/game_icons/cloak-dagger.svg` | The two ability resources' icons |

## `player.tscn` layout GARP relies on

| Node | What GARP needs |
|---|---|
| `Player` (`CharacterBody3D`, group `Player`) | `player.gd`; a collision shape so `Area3D` pickups see it |
| `PlayerModel/Armature/GeneralSkeleton` (`Skeleton3D`) | `player.skeleton`, with the bones equipment names (`RightHand`, `LeftHand`) |
| `Controls` | `player.controls`; `BottomRight/JoypadButton0/Label` is `joypad_button_0_label` |
| `Inventory` (`res://addons/garp/scenes/inventory.tscn`, `player = ..`) | `player.inventory`, `$Inventory/RadialMenu`, `$Inventory/Spellbook` |
| `Abilities` (`player = ..`, `abilities = [stealth.tres, heal.tres]`) | `player.abilities`; the starting spells the Spellbook seeds from |
| `Pause` (`player = ..`, both screen paths set to GARP's screens) | `player.pause`; instances the Inventory and Spells screens as siblings |
| `Crosshair` (`TextureRect`) | `player.crosshair` |
| `HeldObject` | `player.held_object` |
