class_name Conversation
extends Node
## Runs a Dialogic timeline when the [TalkingNpc] this sits under is talked to. The addon's NPC only offers Talk,
## holds the Player still and emits [signal TalkingNpc.talked_to]; what is said is this project's, through
## Dialogic. Before the timeline starts the Player's quest log is published to Dialogic as variables, so a
## timeline branches on [code]{quest.<id>}[/code] ("not_started", "active" or "complete") and
## [code]{objective.<id>}[/code] (true once met). A timeline drives the log back through Dialogic's signal
## event: [code][signal arg="start_quest <id>"][/code] starts one of [member quests],
## [code][signal arg="progress <objective id>"][/code] reports an objective (with a count after it if not 1).
## The Action button advances the text while the conversation runs and reads [member continue_label]; while a
## question is up it reads [member choice_label] and picks the focused choice (Dialogic focuses the first one, and
## the d-pad or stick moves the focus). Start ends the conversation.

const DEFAULT_INPUT_ACTION: String = "dialogic_default_action" ## Dialogic's own action, back in force between conversations.
const INPUT_ACTION_SETTING: String = "dialogic/text/input_action"

@export var timeline: DialogicTimeline ## What this NPC says.
@export var quests: Array[Quest] = [] ## The quests a [code]start_quest[/code] signal in the timeline may start, by their id.
@export var continue_label: String = "Next" ## What the bottom-action button reads while the conversation runs.
@export var choice_label: String = "Pick" ## What it reads while a question is up, when Action picks the focused choice; short, since the face label is narrow.
@export var advance_action: StringName = &"action" ## The Player action that advances the text; Dialogic listens for it while talking.

@export var npc: TalkingNpc ## The NPC this conversation belongs to; its talked_to is connected to [method _on_talked_to] in the scene.

var player: Player ## Who is talking, while somebody is.
var _choosing: bool = false ## A question is up: Action picks the focused choice instead of advancing.


func _on_talked_to(who: Player) -> void:
	if not start(who):
		npc.end_talk()


## Opens [member timeline] for [param who]; false when there is nothing to say or Dialogic is already talking.
func start(who: Player) -> bool:
	if timeline == null or who == null or player or _dialogic() == null or _dialogic().current_timeline != null:
		return false
	player = who
	publish_quests(who.quest_log)
	if who.controls:
		who.controls.claim_action_label(continue_label, self)
	if who.uses_mouse:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	ProjectSettings.set_setting(INPUT_ACTION_SETTING, String(advance_action))
	_dialogic().signal_event.connect(_on_signal_event)
	_dialogic().Choices.question_shown.connect(_on_question_shown)
	_dialogic().Choices.choice_selected.connect(_on_choice_selected)
	_dialogic().timeline_ended.connect(_on_timeline_ended, CONNECT_ONE_SHOT)
	_dialogic().start(timeline)
	return true


## Ends the conversation early, the way the Start button does; Dialogic's end is what lets the Player go.
func end() -> void:
	if player and _dialogic() and _dialogic().current_timeline != null:
		_dialogic().end_timeline(true)


func is_talking() -> bool:
	return player != null


## Writes the quest log into Dialogic's variables: [code]{quest.<id>}[/code] and [code]{objective.<id>}[/code].
func publish_quests(quest_log: QuestLog) -> void:
	var by_quest: Dictionary = {}
	var by_objective: Dictionary = {}
	if quest_log:
		for quest: Quest in quest_log.get_all():
			by_quest[String(quest.get_id())] = _status_name(quest_log.get_status(quest))
			for objective: QuestObjective in quest.objectives:
				by_objective[String(objective.id)] = quest_log.is_objective_done(quest, objective.id)
		for quest: Quest in quests:
			if not by_quest.has(String(quest.get_id())):
				by_quest[String(quest.get_id())] = _status_name(QuestLog.Status.NOT_STARTED)
				for objective: QuestObjective in quest.objectives:
					by_objective[String(objective.id)] = false
	_dialogic().VAR.var_storage["quest"] = by_quest
	_dialogic().VAR.var_storage["objective"] = by_objective


func _on_signal_event(argument: Variant) -> void:
	if player == null or not argument is String:
		return
	var words: PackedStringArray = (argument as String).split(" ", false)
	if words.size() < 2:
		return
	var quest_log: QuestLog = player.quest_log
	if quest_log == null:
		return
	match words[0]:
		"start_quest":
			var quest: Quest = _find_quest(words[1])
			if quest:
				quest_log.start(quest)
		"progress":
			quest_log.progress(StringName(words[1]), int(words[2]) if words.size() > 2 else 1)
	publish_quests(quest_log)


## A question is up: the first choice has the focus (Dialogic's autofocus) and the button reads [member choice_label].
func _on_question_shown(_info: Dictionary) -> void:
	_choosing = true
	if player and player.controls:
		player.controls.claim_action_label(choice_label, self)
	if not get_viewport().gui_get_focus_owner() is DialogicNode_ChoiceButton:
		for node: Node in get_tree().get_nodes_in_group("dialogic_choice_button"):
			if node is DialogicNode_ChoiceButton and (node as DialogicNode_ChoiceButton).is_visible_in_tree():
				(node as DialogicNode_ChoiceButton).grab_focus()
				break


func _on_choice_selected(_info: Dictionary) -> void:
	_choosing = false
	if player and player.controls:
		player.controls.claim_action_label(continue_label, self)


func _on_timeline_ended() -> void:
	var was: Player = player
	player = null
	_choosing = false
	ProjectSettings.set_setting(INPUT_ACTION_SETTING, DEFAULT_INPUT_ACTION)
	if _dialogic().signal_event.is_connected(_on_signal_event):
		_dialogic().signal_event.disconnect(_on_signal_event)
	if _dialogic().Choices.question_shown.is_connected(_on_question_shown):
		_dialogic().Choices.question_shown.disconnect(_on_question_shown)
		_dialogic().Choices.choice_selected.disconnect(_on_choice_selected)
	if is_instance_valid(was):
		if was.controls:
			was.controls.release_action_label(self)
		if was.uses_mouse:
			Input.mouse_mode = was.cursor_mode() # captured, or visible under a scheme that frees it
	if npc:
		npc.end_talk()


func _input(event: InputEvent) -> void:
	if player == null or event.is_echo():
		return
	if event.is_action_pressed(&"start"):
		end()
		get_viewport().set_input_as_handled()
	elif _choosing and event.is_action_pressed(advance_action):
		_dialogic().Choices.select_focused_choice() # the button reads Choose: Action takes the focused choice
		get_viewport().set_input_as_handled()


func _find_quest(id: String) -> Quest:
	for quest: Quest in quests:
		if String(quest.get_id()) == id:
			return quest
	return null


func _status_name(status: QuestLog.Status) -> String:
	match status:
		QuestLog.Status.ACTIVE:
			return "active"
		QuestLog.Status.COMPLETE:
			return "complete"
	return "not_started"


## The Dialogic autoload, or null in a project that has not enabled it.
func _dialogic() -> Node:
	return get_node_or_null("/root/Dialogic")
