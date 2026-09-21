extends SteamTest
## Purpose: a line sent from one side's chat lands in the other side's history under the sender's Steam persona,
## in both directions. ChatWindow._receive_message runs on every peer's copy of the sender's Player and relays to
## the one chat that peer owns.


func test_a_line_from_each_side_lands_in_the_others_history() -> void:
	var chat: ChatWindow = own_player().get_node("Hud/Chat") as ChatWindow
	var line: Dictionary = {"name": chat.get_display_name(), "text": "%s says hello in run %s" % [role, run_id]}
	if is_host:
		chat.send(line["text"])
		mark("host_sent", line)
		await _expect_line(chat, await await_step("client_sent"))
	else:
		await _expect_line(chat, await await_step("host_sent"))
		chat.send(line["text"])
		mark("client_sent", line)
	await barrier("done")


func _expect_line(chat: ChatWindow, sent: Dictionary) -> void:
	await wait_for(func() -> bool: return chat.history.get_parsed_text().contains(sent["text"]), "The other side's line arrives: %s" % sent["text"])
	assert_true(chat.history.get_parsed_text().contains("%s: %s" % [sent["name"], sent["text"]]), "under the sender's persona name, %s" % sent["name"])
