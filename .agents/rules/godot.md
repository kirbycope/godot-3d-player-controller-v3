---
trigger: always_on
---

---

name: godot-rules
description: Godot Engine Coding Guidelines

---

# Godot Coding Rules

Use these rules when altering code and/or making suggested edits.

---

## Rules

- Favor Node over Code. Nodes are a core part of Godot's design. Edit .tscn files to add connections intead of using \_ready() functions.
- Use signals and getters/setters to avoid contant checks in process or physics_process.
- Look for MIT or CC0 based solutions from,
  - Code: https://github.com/search
    - Also a good place to look for shaders
  - Materials: https://ambientcg.com/list?type=material%2Cdecal%2Catlas&sort=popular
  - Models: https://sketchfab.com/search
  - Shaders: https://godotshaders.com/shader)
- I have a private collection of assets I keep in [macOS](tbd) [Windows](C:\GitHub\godot-private-asset-library)
  - Check the /resources directory for \*.tres files that descirbe the content
    - Use mcp to check the assets as needed
- Ask me for sound effects and music when needed, I have some (or can get some) from Itch.io
  - I like the mostly free https://tommusic.itch.io/ and the paid https://gravity-sound.itch.io/
- Keep addons atomic, they should allow interoperability (like `addons/date-and-time` can work with `weather-fx` but the demos are independant.
- Addons should follow this directory structure:
  ```text
  addons/<addon_name>/
  ├── assets/       # Raw media assets (textures, audio SFX/music, models, icons)
  ├── resources/    # Godot resource files (.tres, materials, custom resources, themes)
  ├── scenes/       # Reusable component and prefab scenes (.tscn)
  │   └── demo/     # Standalone demo showcase scenes and interactive test harnesses
  ├── scripts/      # GDScript source code files and node controllers (.gd)
  ├── tests/        # GUT automated unit and integration test suites (test_*.gd)
  ├── .gutconfig.json # GUT configuration file
  ├── plugin.cfg      # Plugin configuration file
  ├── plugin.gd       # Plugin entry point
  └── README.md       # Plugin documentation
  ```

## Acknowledgment

- Before responding to any user request, you MUST acknowledge that you have read and understood the above instructions. You MUST also acknowledge that you will follow the rules and guidelines defined in the above files when writing code, designing systems, or implementing features for this project.
