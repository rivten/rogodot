class_name Ai

# NOTE(rivten): state has nothing
static func basic_monster_take_turn(_entity: Entity, _target: Entity, _game_map: GameMap, can_move_at_pos: FuncRef, _state: Dictionary) -> Array:
	var commands = []
	if GameMap.is_position_visible(_game_map, _entity.pos):
		if Entity.distance_sqr(_entity, _target) >= 4:
			#Entity.move_towards(_entity, _target.pos, can_move_at_pos)
			var from_id = _entity.pos.y * _game_map.width + _entity.pos.x
			var to_id = _target.pos.y * _game_map.width + _target.pos.x
			var path = _game_map.a_star.get_point_path(from_id, to_id)
			assert(path.size() > 1)
			var next_pos = path[1]
			var d = next_pos - _entity.pos
			assert(d.x == 0 or d.x == -1 or d.x == 1)
			assert(d.y == 0 or d.y == -1 or d.y == 1)
			if can_move_at_pos.call_func(_entity.pos.x + d.x, _entity.pos.y + d.y):
				Entity.move(_entity, d.x, d.y)
		else:
			assert(_target.fighter)
			# TODO(rivten): do we really need this check ?
			if _target.fighter.hp >= 0:
				commands = commands + FighterState.attack(_entity.fighter, _target.fighter)

	return commands

# NOTE(rivten): state has previous take_turn (FuncRef) and turn_count
static func confused_monster_take_turn(_entity: Entity, _target: Entity, _game_map: GameMap, can_move_at_pos: FuncRef, _state: Dictionary) -> Array:
	var commands = []
	if _state.turn_count > 0:
		var rand_x = _entity.pos.x + (randi() % 3) - 1
		var rand_y = _entity.pos.y + (randi() % 3) - 1
		if rand_x != _entity.pos.x or rand_y != _entity.pos.y:
			Entity.move_towards(_entity, Vector2(rand_x, rand_y), can_move_at_pos)
		_state.turn_count -= 1
	else:
		# TODO(hugo): should we have a system of a "stack" of ai behaviors ?
		# maybe this ends up being a ai tree ...
		_entity.take_turn = _state.previous_take_turn
		var msg = LogMessage.new()
		msg.text = "The " + _entity.name + " is no longer confused"
		msg.color = Color.red
		commands.push_back({'message': msg})
	return commands
