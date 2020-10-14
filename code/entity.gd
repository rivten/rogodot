class_name Entity

extends Reference

# NOTE(rivten): there is a bad warning that says UNUSED_SIGNAL
# but it is used... https://github.com/godotengine/godot/issues/40496
signal moved(_entity)

var pos: Vector2
var name: String
var blocks: bool

var fighter: FighterState

var inventory: Inventory
var item: Item

# NOTE(rivten): other possibility : attach a script containing the needed functions
var take_turn: FuncRef

# TODO(rivten): should we assert that the vector is not 0 ?
static func move(_entity: Entity, _dx: int, _dy: int) -> void:
	_entity.pos.x += _dx
	_entity.pos.y += _dy

	# TODO(rivten): another possibility : do not emit any signal
	# Instead, at the end of the turn, just update every sprite.
	# Maybe too big operation if there are a lot of entities...
	_entity.emit_signal("moved", _entity)

static func move_towards(_entity: Entity, _target_pos: Vector2, can_move_at_pos: FuncRef) -> void:
	var diff = _target_pos - _entity.pos
	var distance = diff.length()

	var dx = int(round(diff.x / distance))
	var dy = int(round(diff.y / distance))

	if can_move_at_pos.call_func(_entity.pos.x + dx, _entity.pos.y + dy):
		move(_entity, dx, dy)

static func distance_sqr(_entity_a: Entity, _entity_b: Entity) -> int:
	return int((_entity_b.pos - _entity_a.pos).length_squared())

func get_name() -> String:
	return name

func get_self() -> Entity:
	return self
