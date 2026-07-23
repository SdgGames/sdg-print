# Migrating SDG Print from GDScript to GDExtension

The runtime of this addon (loggers, dump writing, viewer data model) is now C++
compiled into a GDExtension library. The editor layer (Print tab, dump viewer,
crash report window) remains GDScript. The motivation: `push_error()` inside a
GDScript logger attributed every error to `logger.gd`, polluting stack traces.
With a native runtime, errors attribute to the line that called
`my_log.error(...)`.

## Building the library

Prerequisites: a C++ toolchain (MSVC Build Tools on Windows, Xcode CLT on
macOS, gcc/clang on Linux), Python 3.x, SCons (`pip install scons`), git.

```
cd addons/sdg-print
git clone https://github.com/godotengine/godot-cpp.git godot-cpp
#   Use the branch/tag matching your Godot version. If your Godot is newer
#   than any godot-cpp branch, use master and confirm the bundled
#   gdextension/extension_api.json header matches your version
#   (`godot --dump-extension-api` produces a reference copy to diff against).
scons target=editor -j8            # library the editor loads
scons target=template_debug -j8    # library for F5 runs / debug exports
scons target=template_release -j8  # for release exports
```

Binaries land in `bin/` next to `sdg_print.gdextension`. Each platform ships
its own library; build on (or cross-compile for) every platform you export to.

## Migrating an existing project

1. **Update the submodule** to the GDExtension version and build (above).
2. **Delete leftovers of the old runtime scripts** if your checkout has stray
   copies (`data_structures/ring_buffer.gd`, `logger/*.gd`,
   `print/print.gd|print_settings.gd|logger_registry.gd`,
   `dumps/error_dump.gd|dump_data.gd|log_node.gd` and their `.uid` files).
   They live on in git history.
3. **Restart the editor once after the scripts are gone.** Godot caches
   `class_name` → script mappings in `.godot/global_script_class_cache.cfg`
   and does not fully drop stale entries on rescan. Symptoms of a stale cache:
   errors like `argument should be "print_settings.gd" but is "PrintSettings"`
   or load spam for the deleted `.gd` files. Deleting
   `.godot/global_script_class_cache.cfg` before the restart guarantees a
   clean rebuild.
4. **Recreate your LoggerRegistry resource.** Saved `.tres` registries
   reference the old script paths and will not load. Recreate with the native
   classes — the file is small enough to port by hand. Keep the original
   `uid="..."` in the header and `debug/logging/logger_registry_path` keeps
   working unchanged:

   ```
   [gd_resource type="LoggerRegistry" load_steps=3 format=3 uid="uid://YOUR_OLD_UID"]

   [sub_resource type="LoggerConfig" id="LoggerConfig_game"]
   name = "Game"
   print_level = 2
   archive_level = 5

   [resource]
   loggers = Array[LoggerConfig]([SubResource("LoggerConfig_game")])
   ```

   (`print_logger` / `global_logger` are optional — defaults are created
   lazily, same as before.)
5. **Enable the plugin** (Project Settings → Plugins → sdg-print). It
   registers the `Print` autoload pointing at
   `res://addons/sdg-print/print/print.tscn` — a scene, because an autoload
   cannot reference a C++ class directly.
6. **Move `Print` to the top of the autoload list.** Startup now happens on
   `ENTER_TREE` of that scene's root; `Print` must enter the tree before any
   autoload that logs from `_ready`.

## Behavioral notes and API differences

- **Constructor arguments don't exist in GDExtension.** If your game code
  constructed runtime classes directly, switch to the `create` statics:
  `RingBuffer.new(n)` → `RingBuffer.create(n)`, `FrameLog.new(t, d)` →
  `FrameLog.create(t, d)`, `LogEntry.new(...)` → `LogEntry.create(...)`,
  `LoggerConfig.new(...)` → `LoggerConfig.create(...)`,
  `LogNode.new(...)` → `LogNode.create(...)`.
  `Log.new()._second_init(...)` still works exactly as before.
- **Native enums have no `.keys()` / `.values()` / `.find_key()`.** Use the
  new statics `Log.level_to_string(level)` / `Log.level_from_string(name)`.
  Dump JSON still stores level *names*, so old dump files load unchanged.
- **`ErrorDump.LATEST_DUMP_PATH`** (a string constant, unbindable from C++)
  is now **`ErrorDump.get_latest_dump_path()`**.
- **The editor pause on error dumps** is `EngineDebugger.debug(true, true)`
  instead of the GDScript `breakpoint` keyword. It fires the debug session's
  `breaked` signal (so the Print tab auto-loads the dump) and is skipped
  when no debugger is attached — same as `breakpoint`.
- `LoggerRegistry`'s `assert(false, ...)` failures are now `ERR_PRINT` +
  fallback default registry in *all* builds (previously debug builds halted).
- The class icons moved from `@icon(...)` annotations to the `[icons]`
  section of `bin/sdg_print.gdextension`.
- `DumpData.LoggerData` (inner class) is registered as top-level `LoggerData`.
