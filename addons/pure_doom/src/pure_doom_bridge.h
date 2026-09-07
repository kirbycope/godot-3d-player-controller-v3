#pragma once

// Engine state read from the C unit. PureDOOM's doom_boolean is a 4-byte enum in C but a 1-byte bool in C++,
// so any struct holding one (player_t, for instance) has a different layout in each language; the C++ node
// must not touch those structs directly.
#ifdef __cplusplus
extern "C" {
#endif

int pure_doom_menu_active(void);
int pure_doom_automap_active(void);
int pure_doom_ready_weapon(void);
int pure_doom_weapon_owned(int weapon);

#ifdef __cplusplus
}
#endif
