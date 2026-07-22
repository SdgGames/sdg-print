#!/usr/bin/env python
# Build script for the SDG Print GDExtension.
# Usage (from this directory):  scons target=editor          - library the editor loads
#                               scons target=template_debug  - library for debug exports / F5 runs
#                               scons target=template_release
env = SConscript("godot-cpp/SConstruct")

env.Append(CPPPATH=["src/"])
sources = Glob("src/*.cpp")

if env["platform"] == "macos":
    library = env.SharedLibrary(
        "bin/libsdg_print.{}.{}.framework/libsdg_print.{}.{}".format(
            env["platform"], env["target"], env["platform"], env["target"]
        ),
        source=sources,
    )
else:
    library = env.SharedLibrary(
        "bin/libsdg_print{}{}".format(env["suffix"], env["SHLIBSUFFIX"]),
        source=sources,
    )

env.NoCache(library)
Default(library)
