class_name PureDoomControls
extends Resource
## The controls card for the DOOM screen: a movement column and an actions column of [PureDoomControl] lines.
## The default card is resources/controls.tres; it documents the mapping in pure_doom.cpp and does not change it.

@export var movement: Array[PureDoomControl] = [] ## Shown on the left of the monitor.
@export var actions: Array[PureDoomControl] = [] ## Shown on the right of the monitor.
