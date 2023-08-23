extends Node
class_name PrintScope

enum {
	GLOBAL,
	MERMAID_PARSER,
	STORY_ENGINE,
}

const modules := {
	GLOBAL: { "name": "Global", "level": Log.LogLevel.VERBOSE, "archive": Log.LogLevel.VERBOSE },
	MERMAID_PARSER: { "name": "Mermaid Parser", "level": Log.LogLevel.WARNING, "archive": Log.LogLevel.DEBUG },
	STORY_ENGINE: { "name": "Story Engine", "level": Log.LogLevel.WARNING, "archive": Log.LogLevel.VERBOSE },
	# Add other modules here...
}
