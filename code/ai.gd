class_name Ai

# TODO(rivten): should the AI know about the map ?? maybe...
static func basic_monster_take_turn(_entity: Entity, _target: Entity, _game_map: GameMap, can_move_at_pos: FuncRef) -> Array:
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
			if _target.fighter.hp > 0:
				commands = commands + FighterState.attack(_entity.fighter, _target.fighter)

	return commands


