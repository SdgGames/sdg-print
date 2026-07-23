#pragma once

#include <godot_cpp/classes/ref.hpp>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/variant.hpp>

namespace godot {

// A fixed-size circular buffer. When full, new pushes overwrite the oldest item.
// Items must implement to_dict() if you want to serialize the buffer.
//
// GDExtension classes cannot take constructor arguments, so GDScript's
// RingBuffer.new(max_size) becomes RingBuffer.create(max_size).
class RingBuffer : public RefCounted {
	GDCLASS(RingBuffer, RefCounted)

	int64_t capacity = 1;
	Array _data;
	int64_t _write_pos = 0;
	int64_t _size = 0;

protected:
	static void _bind_methods();

public:
	static Ref<RingBuffer> create(int64_t p_capacity);

	void set_capacity(int64_t p_capacity); // Resizes and clears the buffer.
	int64_t get_capacity() const { return capacity; }
	int64_t get_size() const { return _size; }

	void push(const Variant &p_item);
	Array get_all() const; // Chronological order, oldest first.
	void clear();

	Dictionary to_dict() const;
	static Ref<RingBuffer> from_dict(const Dictionary &p_data, const Callable &p_item_factory);

	RingBuffer();
};

} // namespace godot
