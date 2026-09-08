// PureDOOM is written in C and must be compiled as C: this unit holds the whole engine.
// The node in pure_doom.cpp only includes the header for the declarations and links against this.
#define DOOM_IMPLEMENTATION
#define DOOM_IMPLEMENT_MALLOC
#include "PureDOOM.h"

#include "pure_doom_bridge.h"

int pure_doom_menu_active(void) {
	return menuactive;
}

int pure_doom_automap_active(void) {
	return automapactive;
}

int pure_doom_ready_weapon(void) {
	return (int)players[consoleplayer].readyweapon;
}

int pure_doom_weapon_owned(int weapon) {
	return weapon >= 0 && weapon < NUMWEAPONS && players[consoleplayer].weaponowned[weapon];
}
