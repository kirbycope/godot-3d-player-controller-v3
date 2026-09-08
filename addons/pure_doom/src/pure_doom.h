#pragma once

#include <godot_cpp/classes/audio_stream_generator_playback.hpp>
#include <godot_cpp/classes/audio_stream_player.hpp>
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/image_texture.hpp>
#include <godot_cpp/classes/input_event.hpp>
#include <godot_cpp/classes/texture_rect.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>

#include <string>
#include <vector>

namespace godot {

// Runs the DOOM engine (PureDOOM) in-process and shows its 320x200 frame as this TextureRect's texture.
// Feed it input events (a SubViewport's push_input reaches _input) and it plays sound through a child
// AudioStreamPlayer. PureDOOM keeps one global engine, so only one PureDoom node can run per process.
class PureDoom : public TextureRect {
	GDCLASS(PureDoom, TextureRect)

	static const int FRAME_WIDTH = 320;
	static const int FRAME_HEIGHT = 200;
	static const int SOUND_FRAMES = 512; // PureDOOM mixes 512 stereo frames at 11025 Hz per call.

	String wad_path = "res://addons/pure_doom/assets/doom1.wad";
	float mouse_sensitivity = 2.0f;
	int skill = 3;

	static bool engine_initialized; // PureDOOM boots once per process; later nodes resume the same game.
	bool running = false;
	double clock_usec = 0.0; // Engine time; only advances while running, so a stopped game never catches up.
	double midi_ticks_due = 0.0; // The music sequencer wants 140 ticks a second; this carries the remainder between frames.
	bool trigger_fire = false;
	int held_stick_keys[6] = { 0, 0, 0, 0, 0, 0 }; // Emulated W, S, A, D from the left stick and the turn arrows from the right.
	int pending_weapon_key = 0; // A weapon slot digit the d-pad is holding down until the engine has seen it.
	double weapon_release_in = 0.0;

	PackedByteArray pixels;
	Ref<Image> image;
	Ref<ImageTexture> texture;
	AudioStreamPlayer *sound_player = nullptr;
	Ref<AudioStreamGeneratorPlayback> playback;

	void present_frame();
	void mix_sound();
	void tick_music(double delta);
	void set_stick_key(int slot, int key, bool down);
	void handle_key(int key, bool pressed);
	void cycle_weapon(int direction);

protected:
	static void _bind_methods();

public:
	static PureDoom *active; // The node whose clock the C callbacks read.
	// The engine keeps the WAD open for the life of the process, so its bytes must outlive any node.
	// Plain C++ types: Godot types cannot be static globals in an extension, their constructors would
	// run when the library loads, before the GDExtension interface exists.
	static std::vector<uint8_t> wad_bytes;
	static std::string wad_name;
	int exit_code = 0;
	bool exit_requested = false;

	PureDoom();
	~PureDoom();

	void _ready() override;
	void _process(double delta) override;
	void _input(const Ref<InputEvent> &event) override;

	void start();
	void stop();
	bool is_running() const;
	bool is_menu_open() const;
	bool is_automap_open() const;
	int get_weapon_slot() const;
	Ref<Image> get_frame() const;
	double get_clock_usec() const;

	void set_wad_path(const String &path);
	String get_wad_path() const;
	void set_mouse_sensitivity(float value);
	float get_mouse_sensitivity() const;
	void set_skill(int value);
	int get_skill() const;
};

} // namespace godot
