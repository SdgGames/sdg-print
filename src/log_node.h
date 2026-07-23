#pragma once

#include "log_entry.h"

#include <godot_cpp/classes/ref.hpp>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/typed_array.hpp>

namespace godot {

// One node in the dump viewer's foldable tree. consume_entries builds the tree
// from a (newest-first) entry list; the fold-point insertion is what the
// viewer's collapse behavior depends on, so it mirrors the GDScript exactly.
class LogNode : public RefCounted {
	GDCLASS(LogNode, RefCounted)

public:
	enum NodeType {
		NODE_TYPE_ROOT = 0, // A module header or dump session header.
		NODE_TYPE_ENTRY = 1, // A regular log entry.
		NODE_TYPE_FOLD_POINT = 2, // A folding marker.
	};

private:
	int type = NODE_TYPE_ENTRY;
	Ref<LogEntry> entry;
	TypedArray<LogNode> children;
	int effective_fold_level = Log::LEVEL_SILENT; // The level at which this node effectively folds.

	int _fold_level = Log::LEVEL_SILENT; // The actual level (== entry.level when entry exists).

	Ref<LogNode> _create_fold_point(int p_level);
	int _look_ahead_for_fold_point(const Array &p_entries);

protected:
	static void _bind_methods();

public:
	// GDScript's LogNode.new(type, entry).
	static Ref<LogNode> create(int p_type, const Ref<LogEntry> &p_entry);

	void set_type(int p_type) { type = p_type; }
	int get_type() const { return type; }
	void set_entry(const Ref<LogEntry> &p_entry) { entry = p_entry; }
	Ref<LogEntry> get_entry() const { return entry; }
	void set_children(const TypedArray<LogNode> &p_children) { children = p_children; }
	TypedArray<LogNode> get_children() const { return children; }
	void set_effective_fold_level(int p_level) { effective_fold_level = p_level; }
	int get_effective_fold_level() const { return effective_fold_level; }

	void add_child(const Ref<LogNode> &p_child);
	void consume_entries(const Array &p_entries);
};

} // namespace godot

VARIANT_ENUM_CAST(godot::LogNode::NodeType);
