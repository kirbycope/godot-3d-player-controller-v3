#!/usr/bin/env python
# Builds the PureDoom GDExtension. From this folder:
#   scons platform=windows target=template_debug
#   scons platform=windows target=template_release
#   scons platform=web threads=no target=template_release   (needs the Emscripten SDK on PATH)
# Add custom_api_file=<extension_api.json> dumped from the Godot build you run, so the bindings match it.
import os

env = SConscript("godot-cpp/SConstruct")

env.Append(CPPPATH=["src/", "thirdparty/"])
# The engine itself is C (pure_doom_impl.c); the node is C++.
sources = Glob("src/*.cpp") + Glob("src/*.c")

if env["platform"] == "macos":
    library = env.SharedLibrary(
        "bin/libpure_doom.{}.{}.framework/libpure_doom.{}.{}".format(
            env["platform"], env["target"], env["platform"], env["target"]
        ),
        source=sources,
    )
else:
    library = env.SharedLibrary(
        "bin/libpure_doom{}{}".format(env["suffix"], env["SHLIBSUFFIX"]),
        source=sources,
    )

Default(library)
