# GodotSteamKit

A collection of extra tools for GodotSteam.  The Kit contains a series of custom nodes, starter kits, autoload scripts, themes, and more all meant to help speed up and streamline working with various parts of Valve's Steamworks SDK.

## Steam Leaderboards

This custom leaderboards scene handles displaying leaderboards and related image UGC; it also comes with an uploading script.  It comes with two child scenes: **Leaderboard Entry** and **Leaderboard UGC** which, as their names imply, are used to handle each component.

While it can be modified to not used them, this starter kit currently requires:
- [Steam Avatar custom nodes](https://codeberg.org/godotsteam/godotsteamkit/src/branch/custom_nodes/avatars)
- [Steam Username custom nodes](https://codeberg.org/godotsteam/godotsteamkit/src/branch/custom_nodes/usernames)
- [Steamworks autoload script](https://codeberg.org/godotsteam/godotsteamkit/src/branch/autoloads)

[For more information on how to use the Steam Lobbies scene, please check out this tutorial.](https://godotsteam.com/tutorials/godotsteamkit/leaderboards)


## Upgrade To The Full Kit

The paid all-in-one kit is available as a Godot plug-in and contains all of the components of the GodotSteamKit including some extras. It will receive new features before they get released as components. It also helps fund future development of both the GodotSteamKit and main GodotSteam project.

- [Full All-In-One Kit On Itch.io](https://godotsteam.itch.io/godotsteamkit)


## Additional Documentation

Each custom scene and custom node should have documentation in the editor; the scripts themselves containing a lot of commenting on how things work.  Or, as mentioned above, there are tutorials for each component in the Kit on [GodotSteam's documentation website](https://godotsteam.com).


## Planned Roadmap

There are quite a few more bits and pieces planned for future updates to the Kit including more starter kits, custom nodes, and etc.  To read more about what is being added, [check out the Planned Roadmap section on the website.](https://godotsteam.com/projects/godotsteamkit/#planned-roadmap)


## Current Version

**Version 1.1**

- Added: custom nodes for achievement icons, both 2D and 3D
- Added: Steam voice custom node
- Added: GodotSteamKit tutorial links to all script documentation
- Fixed: tutorial links in various scripts


## Compatibility

GodotSteamKit is primarily written for Godot 4.x but could be altered to work with Godot 3.x too.  Obviously, it depends heavily on GodotSteam and will work with either the precompiled editor or the GDExtension version.


## License

GodotSteamKit is covered by a [custom GSSL (GodotSteam Software License) license.](https://codeberg.org/godotsteam/godotsteamkit/src/branch/starter_kits/leaderboards/license.md) In short:

- you **may** use the Kit in any free or commerical games or software
- you **may** use the Kit without attribution to Gramps or GodotSteam but keep the license in your project somewhere
- you **may not** distribute, repackage, and/or sell the Kit, in whole or part, anywhere