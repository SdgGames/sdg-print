#include "ring_buffer.h"

#include <godot_cpp/core/class_db.hpp>

using namespace godot;

void RingBuffer::_bind_methods() {
	ClassDB::bind_static_method("RingBuffer", D_METHOD("create", "max_size"), &RingBuffer::create);

	ClassDB::bind_method(D_METHOD("set_capacity", "capacity"), &RingBuffer::set_capacity);
	ClassDB::bind_method(D_METHOD("get_capacity"), &RingBuffer::get_capacity);
	ClassDB::bind_method(D_METHOD("get_size"), &RingBuffer::get_size);
	ADD_PROPERTY(PropertyInfo(Variant::INT, "capacity"), "set_capacity", "get_capacity");
	ADD_PROPERTY(PropertyInfo(Variant::INT, "size"), "", "get_size"); // Read-only, like the GDScript getter.

	ClassDB::bind_method(D_METHOD("push", "item"), &RingBuffer::push);
	ClassDB::bind_method(D_METHOD("get_all"), &RingBuffer::get_all);
	ClassDB::bind_method(D_METHOD("clear"), &RingBuffer::clear);
	ClassDB::bind_method(D_METHOD("to_dict"), &RingBuffer::to_dict);
	ClassDB::bind_static_method("RingBuffer", D_METHOD("from_dict", "data", "item_factory"), &RingBuffer::from_dict);
}

RingBuffer::RingBuffer() {
	_data.resize(capacity);
}

Ref<RingBuffer> RingBuffer::create(int64_t p_capacity) {
	Ref<RingBuffer> buffer;
	buffer.instantiate();
	buffer->set_capacity(p_capacity);
	return buffer;
}

void RingBuffer::set_capacity(int64_t p_capacity) {
	// GDScript's _init would crash later on a zero modulo; fail loudly up front instead.
	ERR_FAIL_COND_MSG(p_capacity < 1, "RingBuffer capacity must be at least 1.");
	capacity = p_capacity;
	clear();
}

void RingBuffer::push(const Variant &p_item) {
	_data[_write_pos] = p_item;
	_write_pos = (_write_pos + 1) % capacity;
	_size = MIN(_size + 1, capacity);
}

Array RingBuffer::get_all() const {
	Array result;
	if (_size == 0) {
		return result;
	}

	// If we haven't wrapped around yet, just return the populated portion.
	if (_size < capacity) {
		for (int64_t i = 0; i < _size; i++) {
			result.push_back(_data[i]);
		}
		return result;
	}

	// If we've wrapped around, reconstruct the chronological order.
	int64_t start_idx = _write_pos; // This is where the oldest item is.
	for (int64_t i = 0; i < capacity; i++) {
		result.push_back(_data[(start_idx + i) % capacity]);
	}
	return result;
}

void RingBuffer::clear() {
	_data.clear();
	_data.resize(capacity);
	_write_pos = 0;
	_size = 0;
}

Dictionary RingBuffer::to_dict() const {
	Array items;
	Array all = get_all();
	for (int64_t i = 0; i < all.size(); i++) {
		// Each item is expected to implement to_dict(), same as the GDScript version.
		items.append(Object::cast_to<Object>(all[i])->call("to_dict"));
	}
	Dictionary dict;
	dict["capacity"] = capacity;
	dict["items"] = items; // Already in chronological order.
	return dict;
}

Ref<RingBuffer> RingBuffer::from_dict(const Dictionary &p_data, const Callable &p_item_factory) {
	Ref<RingBuffer> buffer = create(p_data["capacity"]);
	Array items = p_data["items"];
	for (int64_t i = 0; i < items.size(); i++) {
		buffer->push(p_item_factory.call(items[i]));
	}
	return buffer;
}
