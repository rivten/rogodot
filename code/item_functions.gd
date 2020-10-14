class_name ItemFunctions

static func heal(_d: Dictionary) -> Array:
	var entity = _d.entity
	var amount = _d.amount

	var commands = []

	if entity.fighter.hp == entity.fighter.max_hp:
		var msg = LogMessage.new()
		msg.text = "You are already at full health."
		msg.color = Color.yellow
		commands.push_back({'consumed': false, 'message': msg})
	else:
		FighterState.heal(entity.fighter, amount)
		var msg = LogMessage.new()
		msg.text = "Your wounds start to feel better!"
		msg.color = Color.green
		commands.push_back({'consumed': true, 'message': msg})

	return commands

static func cast_lightning(_d: Dictionary) -> Array:
	var caster = _d.caster
	var entities = _d.entities
	var damage = _d.damage
	var max_range = _d.max_range
	var map = _d.map

	var commands = []

	var target = null
	var closest_distance_sqr = (max_range + 1) * (max_range + 1)
	for entity in entities:
		if entity.fighter and entity != caster and GameMap.is_position_visible(map, entity.pos):
			var dist_sqr = Entity.distance_sqr(entity, caster)
			if dist_sqr < closest_distance_sqr:
				target = entity
				closest_distance_sqr = dist_sqr

	if target:
		var msg = LogMessage.new()
		msg.text = "A lightning bolt strikes the " + target.name + " with a loud thunder. The damage is " + str(damage)
		msg.color = Color.white
		commands.push_back({'consumed': true, 'target': target, 'message': msg})
		commands += FighterState.take_damage(target.fighter, damage)

	return commands

static func cast_fireball(_d: Dictionary) -> Array:
	var entities = _d.entities
	var map = _d.map
	var damage = _d.damage
	var radius = _d.radius
	var target_pos = _d.target_pos

	var commands = []

	if GameMap.is_position_visible(map, target_pos):
		var msg = LogMessage.new()
		msg.text = "The fireball explodes ! Burning everything within " + str(radius) + " tiles !"
		msg.color = Color.orange
		commands.push_back({'consumed': true, 'message': msg})

		for entity in entities:
			if Entity.distance_sqr_to_point(entity, target_pos) <= (radius * radius) and entity.fighter:
				var damage_msg = LogMessage.new()
				damage_msg.text = "The " + entity.name + " gets burned for " + str(damage) + " hit points!"
				damage_msg.color = Color.orange
				commands.push_back({'message': damage_msg})
				commands += FighterState.take_damage(entity.fighter, damage)

	else:
		var msg = LogMessage.new()
		msg.text = "You cannot target a tile outside of your field of view"
		msg.color = Color.yellow
		commands.push_back({'consumed': false, 'message': msg})

	return commands

static func cast_confuse(_d: Dictionary) -> Array:
	var entities = _d.entities
	var map = _d.map
	var target_pos = _d.target_pos

	var commands = []

	if GameMap.is_position_visible(map, target_pos):
		var entity_found = null
		for entity in entities:
			if entity.pos.x == target_pos.x and entity.pos.y == target_pos.y and entity.take_turn:
				entity_found = entity
				break

		if entity_found:
			entity_found.ai_state = {'previous_take_turn': entity_found.take_turn, 'turn_count': 10}
			entity_found.take_turn = funcref(Ai, "confused_monster_take_turn")

			var msg = LogMessage.new()
			msg.text = "The eyes of the " + entity_found.name + " look vacant, he starts to stumble around"
			msg.color = Color.green
			commands.push_back({'consumed': true, 'message': msg})
		else:
			var msg = LogMessage.new()
			msg.text = "There is no targetable entity at that location"
			msg.color = Color.yellow
			commands.push_back({'consumed': false, 'message': msg})

	else:
		var msg = LogMessage.new()
		msg.text = "You cannot target a tile outside of your field of view"
		msg.color = Color.yellow
		commands.push_back({'consumed': false, 'message': msg})

	return commands
