#include "pure_doom.h"

#include <godot_cpp/classes/audio_stream_generator.hpp>
#include <godot_cpp/classes/dir_access.hpp>
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/input_event_joypad_button.hpp>
#include <godot_cpp/classes/input_event_joypad_motion.hpp>
#include <godot_cpp/classes/input_event_key.hpp>
#include <godot_cpp/classes/input_event_midi.hpp>
#include <godot_cpp/classes/input_event_mouse_button.hpp>
#include <godot_cpp/classes/input_event_mouse_motion.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/math.hpp>

#include <cstring>

extern "C" {
#include "PureDOOM.h"
}
#include "pure_doom_bridge.h"

using namespace godot;

PureDoom *PureDoom::active = nullptr;
bool PureDoom::engine_initialized = false;
std::vector<uint8_t> PureDoom::wad_bytes;
std::string PureDoom::wad_name;

// PureDOOM has no OS layer of its own: it asks for time, files, environment and printing through these
// C callbacks. Files are served from memory (the WAD) or from user://pure_doom (config and saves), so the
// same build works on the desktop and in a browser export.
namespace {

const char *SAVE_DIR = "user://pure_doom";

struct DoomFile {
	Ref<FileAccess> file; // Set for config and save files.
	const uint8_t *data = nullptr; // Set for the in-memory WAD.
	int64_t size = 0;
	int64_t position = 0;
};

void doom_print_callback(const char *text) {
	UtilityFunctions::printraw(String::utf8(text));
}

void doom_gettime_callback(int *sec, int *usec) {
	double clock = PureDoom::active ? PureDoom::active->get_clock_usec() : 0.0;
	*sec = int(clock / 1000000.0);
	*usec = int(clock - double(*sec) * 1000000.0);
}

void doom_exit_callback(int code) {
	if (PureDoom::active) {
		PureDoom::active->exit_code = code;
		PureDoom::active->exit_requested = true;
	}
}

char *doom_getenv_callback(const char *name) {
	static char wad_dir[] = "wad";
	static char home_dir[] = "home";
	if (strcmp(name, "DOOMWADDIR") == 0) {
		return wad_dir;
	}
	if (strcmp(name, "HOME") == 0) {
		return home_dir;
	}
	return nullptr;
}

void *doom_open_callback(const char *filename, const char *mode) {
	String name = String::utf8(filename).get_file();
	bool writing = strchr(mode, 'w') != nullptr;
	if (!writing && !PureDoom::wad_bytes.empty() && strcmp(name.to_lower().utf8().get_data(), PureDoom::wad_name.c_str()) == 0) {
		DoomFile *wad = new DoomFile();
		wad->data = PureDoom::wad_bytes.data();
		wad->size = int64_t(PureDoom::wad_bytes.size());
		return wad;
	}
	String path = String(SAVE_DIR) + "/" + name;
	if (writing) {
		DirAccess::make_dir_recursive_absolute(SAVE_DIR);
	} else if (!FileAccess::file_exists(path)) {
		return nullptr;
	}
	Ref<FileAccess> file = FileAccess::open(path, writing ? FileAccess::WRITE : FileAccess::READ);
	if (file.is_null()) {
		return nullptr;
	}
	DoomFile *handle = new DoomFile();
	handle->file = file;
	return handle;
}

void doom_close_callback(void *handle) {
	delete static_cast<DoomFile *>(handle);
}

int doom_read_callback(void *handle, void *buffer, int count) {
	DoomFile *file = static_cast<DoomFile *>(handle);
	if (file->data) {
		int64_t remaining = file->size - file->position;
		int read = int(count < remaining ? count : remaining);
		if (read > 0) {
			memcpy(buffer, file->data + file->position, read);
			file->position += read;
		}
		return read;
	}
	PackedByteArray bytes = file->file->get_buffer(count);
	memcpy(buffer, bytes.ptr(), bytes.size());
	return int(bytes.size());
}

int doom_write_callback(void *handle, const void *buffer, int count) {
	DoomFile *file = static_cast<DoomFile *>(handle);
	if (file->file.is_null()) {
		return 0;
	}
	PackedByteArray bytes;
	bytes.resize(count);
	memcpy(bytes.ptrw(), buffer, count);
	file->file->store_buffer(bytes);
	return count;
}

int doom_seek_callback(void *handle, int offset, doom_seek_t origin) {
	DoomFile *file = static_cast<DoomFile *>(handle);
	if (file->data) {
		int64_t base = origin == DOOM_SEEK_SET ? 0 : (origin == DOOM_SEEK_CUR ? file->position : file->size);
		file->position = base + offset;
		return 0;
	}
	if (origin == DOOM_SEEK_SET) {
		file->file->seek(offset);
	} else if (origin == DOOM_SEEK_CUR) {
		file->file->seek(file->file->get_position() + offset);
	} else {
		file->file->seek_end(offset);
	}
	return 0;
}

int doom_tell_callback(void *handle) {
	DoomFile *file = static_cast<DoomFile *>(handle);
	return int(file->data ? file->position : file->file->get_position());
}

int doom_eof_callback(void *handle) {
	DoomFile *file = static_cast<DoomFile *>(handle);
	return file->data ? file->position >= file->size : file->file->eof_reached();
}

// PureDOOM.h defines C macros named like Godot's keys (KEY_TAB is 9 there, KEY_ESCAPE 27, KEY_F1 187...). Left in
// place they rewrite the Godot constants below, so Tab, Escape, Enter and the F keys never matched; the node only
// ever needs DOOM's keys through the doom_key_t enum, so the macros go.
#undef KEY_BACKSPACE
#undef KEY_DOWNARROW
#undef KEY_ENTER
#undef KEY_EQUALS
#undef KEY_ESCAPE
#undef KEY_F1
#undef KEY_F10
#undef KEY_F11
#undef KEY_F12
#undef KEY_F2
#undef KEY_F3
#undef KEY_F4
#undef KEY_F5
#undef KEY_F6
#undef KEY_F7
#undef KEY_F8
#undef KEY_F9
#undef KEY_LALT
#undef KEY_LEFTARROW
#undef KEY_MINUS
#undef KEY_PAUSE
#undef KEY_RALT
#undef KEY_RCTRL
#undef KEY_RIGHTARROW
#undef KEY_RSHIFT
#undef KEY_TAB
#undef KEY_UPARROW

// Godot key to PureDOOM key; -1 for keys DOOM has no use for.
int doom_key_from(Key key) {
	if (key >= KEY_A && key <= KEY_Z) {
		return DOOM_KEY_A + int(key - KEY_A);
	}
	if (key >= KEY_0 && key <= KEY_9) {
		return DOOM_KEY_0 + int(key - KEY_0);
	}
	if (key >= KEY_F1 && key <= KEY_F12) {
		return DOOM_KEY_F1 + int(key - KEY_F1);
	}
	switch (key) {
		case KEY_QUOTELEFT: return DOOM_KEY_ESCAPE; // DOOM's menu, since a host scene usually keeps Escape for itself
		case KEY_TAB: return DOOM_KEY_TAB;
		case KEY_ENTER: return DOOM_KEY_ENTER;
		case KEY_KP_ENTER: return DOOM_KEY_ENTER;
		case KEY_ESCAPE: return DOOM_KEY_ESCAPE;
		case KEY_SPACE: return DOOM_KEY_SPACE;
		case KEY_BACKSPACE: return DOOM_KEY_BACKSPACE;
		case KEY_CTRL: return DOOM_KEY_CTRL;
		case KEY_SHIFT: return DOOM_KEY_SHIFT;
		case KEY_ALT: return DOOM_KEY_ALT;
		case KEY_LEFT: return DOOM_KEY_LEFT_ARROW;
		case KEY_RIGHT: return DOOM_KEY_RIGHT_ARROW;
		case KEY_UP: return DOOM_KEY_UP_ARROW;
		case KEY_DOWN: return DOOM_KEY_DOWN_ARROW;
		case KEY_MINUS: return DOOM_KEY_MINUS;
		case KEY_EQUAL: return DOOM_KEY_EQUALS;
		case KEY_COMMA: return DOOM_KEY_COMMA;
		case KEY_PERIOD: return DOOM_KEY_PERIOD;
		case KEY_SLASH: return DOOM_KEY_SLASH;
		case KEY_SEMICOLON: return DOOM_KEY_SEMICOLON;
		case KEY_APOSTROPHE: return DOOM_KEY_APOSTROPHE;
		case KEY_BRACKETLEFT: return DOOM_KEY_LEFT_BRACKET;
		case KEY_BRACKETRIGHT: return DOOM_KEY_RIGHT_BRACKET;
		case KEY_ASTERISK: return DOOM_KEY_MULTIPLY;
		case KEY_PAUSE: return DOOM_KEY_PAUSE;
		default: return -1;
	}
}

// Pad buttons: A uses, X fires, B accepts, Y runs, Back opens the menu, and the d-pad is the arrows (which is
// what the menu wants; in the game _input gives the d-pad the automap, the menu and weapon cycling instead).
int doom_key_from_joy_button(JoyButton button) {
	switch (button) {
		case JOY_BUTTON_A: return DOOM_KEY_SPACE;
		case JOY_BUTTON_B: return DOOM_KEY_ENTER;
		case JOY_BUTTON_X: return DOOM_KEY_CTRL;
		case JOY_BUTTON_Y: return DOOM_KEY_SHIFT;
		case JOY_BUTTON_BACK: return DOOM_KEY_ESCAPE;
		case JOY_BUTTON_DPAD_UP: return DOOM_KEY_UP_ARROW;
		case JOY_BUTTON_DPAD_DOWN: return DOOM_KEY_DOWN_ARROW;
		case JOY_BUTTON_DPAD_LEFT: return DOOM_KEY_LEFT_ARROW;
		case JOY_BUTTON_DPAD_RIGHT: return DOOM_KEY_RIGHT_ARROW;
		default: return -1;
	}
}

} // namespace

void PureDoom::_bind_methods() {
	ClassDB::bind_method(D_METHOD("start"), &PureDoom::start);
	ClassDB::bind_method(D_METHOD("stop"), &PureDoom::stop);
	ClassDB::bind_method(D_METHOD("is_running"), &PureDoom::is_running);
	ClassDB::bind_method(D_METHOD("is_menu_open"), &PureDoom::is_menu_open);
	ClassDB::bind_method(D_METHOD("is_automap_open"), &PureDoom::is_automap_open);
	ClassDB::bind_method(D_METHOD("get_weapon_slot"), &PureDoom::get_weapon_slot);
	ClassDB::bind_method(D_METHOD("get_frame"), &PureDoom::get_frame);

	ClassDB::bind_method(D_METHOD("set_wad_path", "path"), &PureDoom::set_wad_path);
	ClassDB::bind_method(D_METHOD("get_wad_path"), &PureDoom::get_wad_path);
	ClassDB::bind_method(D_METHOD("set_mouse_sensitivity", "value"), &PureDoom::set_mouse_sensitivity);
	ClassDB::bind_method(D_METHOD("get_mouse_sensitivity"), &PureDoom::get_mouse_sensitivity);
	ClassDB::bind_method(D_METHOD("set_skill", "value"), &PureDoom::set_skill);
	ClassDB::bind_method(D_METHOD("get_skill"), &PureDoom::get_skill);

	ADD_PROPERTY(PropertyInfo(Variant::STRING, "wad_path", PROPERTY_HINT_FILE, "*.wad,*.WAD"), "set_wad_path", "get_wad_path");
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "mouse_sensitivity", PROPERTY_HINT_RANGE, "0.1,10,0.1"), "set_mouse_sensitivity", "get_mouse_sensitivity");
	ADD_PROPERTY(PropertyInfo(Variant::INT, "skill", PROPERTY_HINT_RANGE, "1,5,1"), "set_skill", "get_skill");

	ADD_SIGNAL(MethodInfo("exited", PropertyInfo(Variant::INT, "code")));
	// The music: DOOM's sequencer output as MIDI events, for a synthesiser such as Godot MIDI Player's receive_raw_midi_message
	ADD_SIGNAL(MethodInfo("midi_message", PropertyInfo(Variant::OBJECT, "event", PROPERTY_HINT_RESOURCE_TYPE, "InputEventMIDI")));
}

PureDoom::PureDoom() {
	pixels.resize(FRAME_WIDTH * FRAME_HEIGHT * 4);
	pixels.fill(0);
}

PureDoom::~PureDoom() {
	if (active == this) {
		active = nullptr;
	}
}

void PureDoom::_ready() {
	set_expand_mode(TextureRect::EXPAND_IGNORE_SIZE);
	set_stretch_mode(TextureRect::STRETCH_SCALE);
	image = Image::create_from_data(FRAME_WIDTH, FRAME_HEIGHT, false, Image::FORMAT_RGBA8, pixels);
	texture = ImageTexture::create_from_image(image);
	set_texture(texture);
	if (Engine::get_singleton()->is_editor_hint()) {
		return;
	}

	Ref<AudioStreamGenerator> generator;
	generator.instantiate();
	generator->set_mix_rate(DOOM_SAMPLERATE);
	generator->set_buffer_length(0.2f);
	sound_player = memnew(AudioStreamPlayer);
	sound_player->set_stream(generator);
	add_child(sound_player);

	set_process(false);
	set_process_input(true);
}

// Boots the engine on the first call (PureDOOM initialises once per process) and resumes it afterwards.
void PureDoom::start() {
	if (running || Engine::get_singleton()->is_editor_hint()) {
		return;
	}
	if (active && active != this) {
		UtilityFunctions::push_warning("PureDoom: another PureDoom node already owns the engine.");
		return;
	}
	active = this;
	// Loaded once for the process: the engine's open WAD handle points into these bytes from now on
	if (wad_bytes.empty()) {
		PackedByteArray bytes = FileAccess::get_file_as_bytes(wad_path);
		if (bytes.is_empty()) {
			UtilityFunctions::push_error("PureDoom: cannot read WAD at ", wad_path);
			active = nullptr;
			return;
		}
		wad_bytes.assign(bytes.ptr(), bytes.ptr() + bytes.size());
		wad_name = wad_path.get_file().to_lower().utf8().get_data();
	}
	if (!engine_initialized) {

		doom_set_print(doom_print_callback);
		doom_set_gettime(doom_gettime_callback);
		doom_set_exit(doom_exit_callback);
		doom_set_getenv(doom_getenv_callback);
		doom_set_file_io(doom_open_callback, doom_close_callback, doom_read_callback, doom_write_callback,
				doom_seek_callback, doom_tell_callback, doom_eof_callback);

		// Modern bindings: WASD walks, Space uses (the pad's A sends Space too), the mouse turns but never walks.
		// Letters stay themselves so the cheat codes can be typed.
		doom_set_default_int("key_up", DOOM_KEY_W);
		doom_set_default_int("key_down", DOOM_KEY_S);
		doom_set_default_int("key_strafeleft", DOOM_KEY_A);
		doom_set_default_int("key_straferight", DOOM_KEY_D);
		doom_set_default_int("mouse_move", 0);

		// Straight into E1M1: the title loop and its menu need Escape, which the host keeps for itself.
		// The engine keeps pointing at argv for the life of the process (M_CheckParm runs on every level load),
		// so it must not be a local.
		static char skill_text[2] = { '3', 0 };
		static char *argv[] = { (char *)"pure_doom", (char *)"-warp", (char *)"1", (char *)"1", (char *)"-skill", skill_text };
		skill_text[0] = char('0' + skill);
		doom_init(6, argv, DOOM_FLAG_MENU_DARKEN_BG);
		engine_initialized = true;
	}
	running = true;
	set_process(true);
	if (sound_player) {
		sound_player->play();
		playback = sound_player->get_stream_playback();
	}
}

// Freezes the game where it is; start() picks it up again with no lost time to catch up on.
void PureDoom::stop() {
	running = false;
	set_process(false);
	for (int slot = 0; slot < 6; slot++) {
		set_stick_key(slot, held_stick_keys[slot], false);
	}
	if (trigger_fire) {
		handle_key(DOOM_KEY_CTRL, false);
		trigger_fire = false;
	}
	if (pending_weapon_key != 0) {
		doom_key_up(doom_key_t(pending_weapon_key));
		pending_weapon_key = 0;
	}
	if (sound_player) {
		sound_player->stop();
	}
	playback.unref();
}

bool PureDoom::is_running() const {
	return running;
}

// Whether DOOM's own menu is overlaid (the engine's menuactive flag).
bool PureDoom::is_menu_open() const {
	return engine_initialized && pure_doom_menu_active() != 0;
}

bool PureDoom::is_automap_open() const {
	return engine_initialized && pure_doom_automap_active() != 0;
}

// The number key slot of the weapon in hand: 1 fist or chainsaw, 2 pistol, 3 shotgun, 4 chaingun, 5 rockets,
// 6 plasma, 7 BFG.
int PureDoom::get_weapon_slot() const {
	if (!engine_initialized) {
		return 0;
	}
	int weapon = pure_doom_ready_weapon();
	return weapon == 7 ? 1 : weapon + 1;
}

// Presses the number of the next owned weapon slot in [param direction] and lets go a couple of tics later,
// long enough for the engine to see it.
void PureDoom::cycle_weapon(int direction) {
	if (pending_weapon_key != 0 || !engine_initialized) {
		return;
	}
	int slot = get_weapon_slot();
	for (int step = 0; step < 7; step++) {
		slot = ((slot - 1 + direction + 7) % 7) + 1;
		bool owned = slot == 1 || pure_doom_weapon_owned(slot - 1) != 0;
		if (owned) {
			pending_weapon_key = DOOM_KEY_1 + slot - 1;
			weapon_release_in = 0.08;
			doom_key_down(doom_key_t(pending_weapon_key));
			return;
		}
	}
}

// The last 320x200 frame as an Image, updated on the CPU every tick whatever the renderer.
Ref<Image> PureDoom::get_frame() const {
	return image;
}

double PureDoom::get_clock_usec() const {
	return clock_usec;
}

void PureDoom::_process(double delta) {
	if (!running) {
		return;
	}
	clock_usec += delta * 1000000.0;
	if (pending_weapon_key != 0) {
		weapon_release_in -= delta;
		if (weapon_release_in <= 0.0) {
			doom_key_up(doom_key_t(pending_weapon_key));
			pending_weapon_key = 0;
		}
	}
	doom_update();
	if (exit_requested) {
		exit_requested = false;
		stop();
		emit_signal("exited", exit_code);
		return;
	}
	present_frame();
	mix_sound();
	tick_music(delta);
}

// Runs the sequencer at its 140 Hz and hands every MIDI message out as an InputEventMIDI. The packing is
// the classic short message: status in the low byte, then the two data bytes.
void PureDoom::tick_music(double delta) {
	midi_ticks_due += delta * DOOM_MIDI_RATE;
	if (midi_ticks_due > 8.0) {
		midi_ticks_due = 8.0; // After a hitch, skip ahead rather than replay a burst
	}
	while (midi_ticks_due >= 1.0) {
		midi_ticks_due -= 1.0;
		unsigned long message = doom_tick_midi();
		while (message != 0) {
			int status = int(message & 0xF0);
			int data1 = int((message >> 8) & 0x7F);
			int data2 = int((message >> 16) & 0x7F);
			Ref<InputEventMIDI> event;
			event.instantiate();
			event->set_channel(int(message & 0x0F));
			switch (status) {
				case 0x80:
					event->set_message(MIDI_MESSAGE_NOTE_OFF);
					event->set_pitch(data1);
					event->set_velocity(data2);
					break;
				case 0x90:
					event->set_message(data2 > 0 ? MIDI_MESSAGE_NOTE_ON : MIDI_MESSAGE_NOTE_OFF);
					event->set_pitch(data1);
					event->set_velocity(data2);
					break;
				case 0xA0:
					event->set_message(MIDI_MESSAGE_AFTERTOUCH);
					event->set_pitch(data1);
					event->set_pressure(data2);
					break;
				case 0xB0:
					event->set_message(MIDI_MESSAGE_CONTROL_CHANGE);
					event->set_controller_number(data1);
					event->set_controller_value(data2);
					break;
				case 0xC0:
					event->set_message(MIDI_MESSAGE_PROGRAM_CHANGE);
					event->set_instrument(data1);
					break;
				case 0xD0:
					event->set_message(MIDI_MESSAGE_CHANNEL_PRESSURE);
					event->set_pressure(data1);
					break;
				case 0xE0:
					event->set_message(MIDI_MESSAGE_PITCH_BEND);
					event->set_pitch(data1 | (data2 << 7));
					break;
				default:
					message = doom_tick_midi();
					continue;
			}
			emit_signal("midi_message", event);
			message = doom_tick_midi();
		}
	}
}

void PureDoom::present_frame() {
	const unsigned char *frame = doom_get_framebuffer(4);
	memcpy(pixels.ptrw(), frame, pixels.size());
	image->set_data(FRAME_WIDTH, FRAME_HEIGHT, false, Image::FORMAT_RGBA8, pixels);
	texture->update(image);
}

// Pulls 512-frame chunks from the engine whenever the generator has room for them.
void PureDoom::mix_sound() {
	if (playback.is_null()) {
		return;
	}
	int available = playback->get_frames_available();
	PackedVector2Array chunk;
	chunk.resize(SOUND_FRAMES);
	while (available >= SOUND_FRAMES) {
		const short *samples = doom_get_sound_buffer();
		Vector2 *frames = chunk.ptrw();
		for (int i = 0; i < SOUND_FRAMES; i++) {
			frames[i] = Vector2(samples[i * 2] / 32768.0f, samples[i * 2 + 1] / 32768.0f);
		}
		playback->push_buffer(chunk);
		available -= SOUND_FRAMES;
	}
}

void PureDoom::handle_key(int key, bool pressed) {
	if (key < 0) {
		return;
	}
	if (pressed) {
		doom_key_down(doom_key_t(key));
	} else {
		doom_key_up(doom_key_t(key));
	}
}

// The left stick emulates W, S, A and D; a slot remembers which key it is holding so it can let go.
void PureDoom::set_stick_key(int slot, int key, bool down) {
	int held = held_stick_keys[slot];
	if (down && held != key) {
		if (held) {
			handle_key(held, false);
		}
		handle_key(key, true);
		held_stick_keys[slot] = key;
	} else if (!down && held) {
		handle_key(held, false);
		held_stick_keys[slot] = 0;
	}
}

void PureDoom::_input(const Ref<InputEvent> &event) {
	if (!running || event.is_null()) {
		return;
	}
	Ref<InputEventKey> key_event = event;
	if (key_event.is_valid()) {
		if (key_event->is_echo()) {
			return;
		}
		Key code = key_event->get_keycode();
		if (code == KEY_NONE) {
			code = key_event->get_physical_keycode();
		}
		handle_key(doom_key_from(code), key_event->is_pressed());
		return;
	}
	Ref<InputEventMouseMotion> motion = event;
	if (motion.is_valid()) {
		doom_mouse_move(int(motion->get_relative().x * mouse_sensitivity), 0);
		return;
	}
	Ref<InputEventMouseButton> mouse_button = event;
	if (mouse_button.is_valid()) {
		int button = -1;
		switch (mouse_button->get_button_index()) {
			case MOUSE_BUTTON_LEFT: button = DOOM_LEFT_BUTTON; break;
			case MOUSE_BUTTON_RIGHT: button = DOOM_RIGHT_BUTTON; break;
			case MOUSE_BUTTON_MIDDLE: button = DOOM_MIDDLE_BUTTON; break;
			default: return;
		}
		if (mouse_button->is_pressed()) {
			doom_button_down(doom_button_t(button));
		} else {
			doom_button_up(doom_button_t(button));
		}
		return;
	}
	Ref<InputEventJoypadButton> joy_button = event;
	if (joy_button.is_valid()) {
		JoyButton button = joy_button->get_button_index();
		bool pressed = joy_button->is_pressed();
		// With the menu up the d-pad is its arrow keys; in the game it is the automap, the menu and the weapons
		if (!pure_doom_menu_active()) {
			switch (button) {
				case JOY_BUTTON_DPAD_UP: handle_key(DOOM_KEY_TAB, pressed); return;
				case JOY_BUTTON_DPAD_DOWN: handle_key(DOOM_KEY_ESCAPE, pressed); return;
				case JOY_BUTTON_DPAD_LEFT: if (pressed) { cycle_weapon(-1); } return;
				case JOY_BUTTON_DPAD_RIGHT: if (pressed) { cycle_weapon(1); } return;
				default: break;
			}
		}
		handle_key(doom_key_from_joy_button(button), pressed);
		return;
	}
	Ref<InputEventJoypadMotion> joy_motion = event;
	if (joy_motion.is_valid()) {
		float value = joy_motion->get_axis_value();
		switch (joy_motion->get_axis()) {
			case JOY_AXIS_LEFT_X:
				set_stick_key(2, DOOM_KEY_A, value < -0.5f);
				set_stick_key(3, DOOM_KEY_D, value > 0.5f);
				break;
			case JOY_AXIS_LEFT_Y:
				set_stick_key(0, DOOM_KEY_W, value < -0.5f);
				set_stick_key(1, DOOM_KEY_S, value > 0.5f);
				break;
			case JOY_AXIS_RIGHT_X:
				set_stick_key(4, DOOM_KEY_LEFT_ARROW, value < -0.4f);
				set_stick_key(5, DOOM_KEY_RIGHT_ARROW, value > 0.4f);
				break;
			case JOY_AXIS_TRIGGER_RIGHT: {
				bool fire = value > 0.5f;
				if (fire != trigger_fire) {
					trigger_fire = fire;
					handle_key(DOOM_KEY_CTRL, fire);
				}
				break;
			}
			default:
				break;
		}
	}
}

void PureDoom::set_wad_path(const String &path) {
	wad_path = path;
}

String PureDoom::get_wad_path() const {
	return wad_path;
}

void PureDoom::set_mouse_sensitivity(float value) {
	mouse_sensitivity = value;
}

float PureDoom::get_mouse_sensitivity() const {
	return mouse_sensitivity;
}

void PureDoom::set_skill(int value) {
	skill = value < 1 ? 1 : (value > 5 ? 5 : value);
}

int PureDoom::get_skill() const {
	return skill;
}
