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
