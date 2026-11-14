# sdg-print
A custom logging class for Godot 4. Provides logging per module with multiple levels.

## Project settings

All settings live under `debug/logging/` in the Project Settings and are read
with feature-tag overrides, so a value can differ per build
(`debug/logging/dumps/enabled.web=false`).

| Setting | Default | Meaning |
| --- | --- | --- |
| `logger_registry_path` | empty | The `LoggerRegistry` resource that defines the project's loggers. |
| `require_registry` | on | Report an error when no registry is set. |
| `history/max_log_entries` | 1000 | Messages each logger keeps for the next dump. |
| `history/max_frames` | 100 | Frame logs each logger keeps. |
| `history/max_log_files` | 15 | Dump files kept from earlier sessions (`-1` keeps all). |
| `dumps/enabled` | on | Write dump files (on errors, on request, and when a debug build closes). Off: no dump file or folder is ever created. |
| `dumps/directory` | `user://dumps` | Folder the dump files are written to. It is created by the first dump. It may hold other files too: only the dump files (`error_dump_*.json`, `latest_dump.json`) are listed and cleaned up. |
| `format/*`, `colors/*` | | How printed lines look. |

See [MIGRATION.md](MIGRATION.md) for building the library and for the changes
since the GDScript version.
