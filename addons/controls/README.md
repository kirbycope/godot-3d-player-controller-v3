This repository **is** that project. It uses the layout the
[Godot Asset Library](https://docs.godotengine.org/en/stable/community/asset_library/submitting_to_assetlib.html) expects, with the addon at `addons/controls/` and a
`project.godot` at the root, so you can clone it, open it in Godot and edit the addon in
place. Nothing is copied anywhere first, and the root `project.godot` is skipped as a
conflict when the asset is installed from the library.

There used to be a second Godot project under `demo/` holding a `robocopy` mirror of this
repository. It is gone: it meant the only project that mounted the addon held a throwaway
copy, so edits made there were destroyed by the next mirror.

Then open this repository in Godot.

## Tests

```powershell
& 'C:\Godot\godot.exe' --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://addons/controls/tests -gexit
```

## Credits and licenses

| What | Author | License | Source |
| --- | --- | --- | --- |
| `assets/kenney_nl/Icons/Input Prompts/` | Kenney | CC0 1.0 (`License.txt` beside them) | <https://kenney.nl/assets/input-prompts> |
| Everything else | Tim Cope | MIT (`LICENSE`) | |

The HUD and the world prompt were part of
[godot-3d-player-controller-addon](https://github.com/kirbycope/godot-3d-player-controller-addon) before this
repository, and were lifted out of it so projects with no player controller could use them.
