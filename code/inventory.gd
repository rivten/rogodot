class_name Inventory

extends Reference

var capacity: int
var items : Array

static func add_item(_inventory: Inventory, _item_weak_ref: WeakRef) -> Array:
	var commands = []

	if _inventory.items.size() >= _inventory.capacity:
		var msg = LogMessage.new()
		msg.text = "You cannot carry any more, your inventory is full"
		msg.color = Color.yellow
		commands.push_back({'message': msg})
	else:
		var msg = LogMessage.new()
		msg.text = "You pick the " + _item_weak_ref.get_ref().name + "!"
		msg.color = Color.blue
		commands.push_back({
			'item_added': _item_weak_ref,
			'message': msg })
		_inventory.items.push_back(_item_weak_ref)

	return commands

static func use_item(_inventory: Inventory, _item_index: int, _d: Dictionary) -> Array:
	var item_entity = _inventory.items[_item_index].get_ref()
	var commands = []

	if not item_entity.item.use_function:
		var msg = LogMessage.new()
		msg.text = "The " + item_entity.name + " cannot be used."
		msg.color = Color.yellow
	else:
		if item_entity.item.targeting and (not _d.has('target_pos')):
			commands.push_back({'targeting_item': item_entity, 'targeting_item_index': _item_index})
		else:
			commands = item_entity.item.use(_d)

			for command in commands:
				if command.has('consumed') and command.consumed:
					remove_item(_inventory, _item_index)

	return commands

static func remove_item(_inventory: Inventory, _item_index: int) -> void:
	_inventory.items.remove(_item_index)


static func drop_item(_inventory: Inventory, _item_index: int, _pos: Vector2) -> Array:
	var commands = []

	var item_entity = _inventory.items[_item_index].get_ref()

	# TODO(rivten): bundle these two lines into one in the Entity code ?
	item_entity.pos = _pos
	item_entity.emit_signal("moved", item_entity)

	remove_item(_inventory, _item_index)

	var msg = LogMessage.new()
	msg.text = "You dropped the " + item_entity.name
	msg.color = Color.yellow
	commands.push_back({'item_dropped': item_entity, 'message': msg})

	return commands

