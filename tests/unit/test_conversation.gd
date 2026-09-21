extends GutTest

## Purpose: A Conversation under a TalkingNpc runs a Dialogic timeline when the NPC is talked to: the Player is
## held still and the bottom button reads Continue while it runs, the quest log is published to Dialogic as
## variables the timeline can branch on, a signal event in the timeline starts a quest or reports an objective,
## and the end of the timeline lets the NPC and the Player go.

const PLAYER_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/player.tscn")
const NPC_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/npc/talking_npc.tscn")

var root: Node3D
var player: Player
var npc: TalkingNpc
var conversation: Conversation
var quest: Quest


func before_each() -> void:
	root = Node3D.new()
	add_child_autofree(root)
	var floor_body: StaticBody3D = StaticBody3D.new()
	var floor_shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(40.0, 1.0, 40.0)
	floor_shape.shape = box
	floor_body.add_child(floor_shape)
	floor_body.position.y = -0.5
	root.add_child(floor_body)
	player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	quest = Quest.new()
	quest.id = &"errand"
	var objective: QuestObjective = QuestObjective.new()
	objective.id = &"talk"
	quest.objectives.append(objective)
	npc = NPC_SCENE.instantiate()
	conversation = Conversation.new()
	conversation.name = "Conversation"
	conversation.quests = [quest]
	npc.add_child(conversation)
	root.add_child(npc)
	npc.global_position = player.global_position + Vector3(0.0, 0.0, -2.0)
	Dialogic.Settings.text_speed = 0.0
	await wait_physics_frames(2)


func after_each() -> void:
	if Dialogic.current_timeline != null:
		Dialogic.end_timeline(true)
		await wait_process_frames(2)


func _timeline(text: String) -> DialogicTimeline:
	var timeline: DialogicTimeline = DialogicTimeline.new()
	timeline.from_text(text)
	return timeline


func test_a_talk_runs_the_timeline_and_the_end_lets_everyone_go() -> void:
	conversation.timeline = _timeline("Hello there.\nAnd goodbye.")
	assert_true(npc.talk(player))
	await wait_process_frames(3)
	assert_true(conversation.is_talking())
	assert_eq(Dialogic.current_timeline, conversation.timeline, "The NPC's timeline is the one running")
	assert_true(player.is_paused, "The Player stands still while talking")
	assert_eq(player.controls.prompt_action_label, "Continue", "The bottom button reads Continue")
	assert_eq(ProjectSettings.get_setting(Conversation.INPUT_ACTION_SETTING), "action", "Action advances the text")
	conversation.end()
	await wait_process_frames(3)
	assert_false(conversation.is_talking())
	assert_null(Dialogic.current_timeline)
	assert_false(player.is_paused, "Let go when the timeline ends")
	assert_null(npc.talker)
	assert_eq(player.controls.prompt_action_label, "", "The label is given back")
	assert_eq(ProjectSettings.get_setting(Conversation.INPUT_ACTION_SETTING), Conversation.DEFAULT_INPUT_ACTION)


func test_the_quest_log_is_published_as_dialogic_variables() -> void:
	conversation.timeline = _timeline("Hello.")
	assert_true(npc.talk(player))
	await wait_process_frames(3)
	assert_eq(Dialogic.VAR.get_variable("quest.errand"), "not_started", "A quest the NPC can hand out, not yet taken")
	assert_eq(Dialogic.VAR.get_variable("objective.talk"), false)
	conversation.end()
	await wait_process_frames(3)
	player.quest_log.start(quest)
	assert_true(npc.talk(player))
	await wait_process_frames(3)
	assert_eq(Dialogic.VAR.get_variable("quest.errand"), "active")
	conversation.end()
	await wait_process_frames(3)
	player.quest_log.progress(&"talk")
	assert_true(npc.talk(player))
	await wait_process_frames(3)
	assert_eq(Dialogic.VAR.get_variable("quest.errand"), "complete")
	assert_eq(Dialogic.VAR.get_variable("objective.talk"), true)


func test_signal_events_in_the_timeline_drive_the_quest_log() -> void:
	conversation.timeline = _timeline('[signal arg="start_quest errand"]\n[signal arg="progress talk"]\nDone.')
	var quest_log: QuestLog = player.quest_log
	assert_true(npc.talk(player))
	await wait_process_frames(4)
	assert_true(quest_log.is_complete(quest), "start_quest took the errand and progress met its one objective")
	assert_eq(Dialogic.VAR.get_variable("quest.errand"), "complete", "The variables follow the log as it changes")


func test_a_timeline_can_branch_on_the_quest() -> void:
	conversation.timeline = _timeline('if {quest.errand} == "active":\n\t[signal arg="progress talk"]\nelse:\n\t[signal arg="start_quest errand"]\nDone.')
	var quest_log: QuestLog = player.quest_log
	assert_true(npc.talk(player))
	await wait_process_frames(4)
	assert_true(quest_log.is_active(quest), "Not started: the else branch starts it")
	assert_false(quest_log.is_complete(quest))
	conversation.end()
	await wait_process_frames(3)
	assert_true(npc.talk(player))
	await wait_process_frames(4)
	assert_true(quest_log.is_complete(quest), "Active: the if branch reports the objective")


func test_the_start_button_ends_a_conversation() -> void:
	conversation.timeline = _timeline("Hello there.")
	assert_true(npc.talk(player))
	await wait_process_frames(3)
	var event: InputEventAction = InputEventAction.new()
	event.action = &"start"
	event.pressed = true
	conversation._input(event)
	await wait_process_frames(3)
	assert_false(conversation.is_talking())
	assert_false(player.is_paused)


func test_an_npc_with_nothing_to_say_lets_the_player_go_at_once() -> void:
	conversation.timeline = null
	assert_true(npc.talk(player))
	await wait_process_frames(1)
	assert_false(conversation.is_talking())
	assert_null(npc.talker, "No timeline: the talk ends as it begins")
	assert_false(player.is_paused)
