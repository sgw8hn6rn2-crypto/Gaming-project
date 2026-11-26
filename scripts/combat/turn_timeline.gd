class_name TurnTimeline
extends RefCounted
## Decides who acts next. Each tick every living battler gains gauge equal to
## its speed; whoever reaches 100 first acts. Array order breaks ties.

var battlers: Array[Battler] = []


func _init(list: Array[Battler]) -> void:
	battlers = list.duplicate()


func next_actor() -> Battler:
	var gauges := _gauges()
	var idx := _step(gauges)
	if idx < 0:
		return null
	for i in battlers.size():
		battlers[i].gauge = gauges[i]
	return battlers[idx]


## The next n actors, without changing anyone's gauge.
func preview(n: int) -> Array[Battler]:
	var gauges := _gauges()
	var out: Array[Battler] = []
	for _i in n:
		var idx := _step(gauges)
		if idx < 0:
			break
		out.append(battlers[idx])
	return out


## Puts incoming in outgoing's slot. Incoming inherits the gauge so swapping
## never grants an extra turn.
func replace(outgoing: Battler, incoming: Battler) -> void:
	var i := battlers.find(outgoing)
	if i < 0:
		return
	incoming.gauge = outgoing.gauge
	battlers[i] = incoming


func _gauges() -> PackedFloat32Array:
	var g := PackedFloat32Array()
	for b in battlers:
		g.append(b.gauge)
	return g


## Advances gauges in place and returns the index of the actor, or -1 if
## nobody can act. The actor's gauge drops by GAUGE_FULL.
func _step(g: PackedFloat32Array) -> int:
	var any_alive := false
	for b in battlers:
		if not b.is_ko():
			any_alive = true
			break
	if not any_alive:
		return -1
	while true:
		var best := -1
		for i in battlers.size():
			if battlers[i].is_ko() or g[i] < Tuning.GAUGE_FULL:
				continue
			if best < 0 or g[i] > g[best]:
				best = i
		if best >= 0:
			g[best] -= Tuning.GAUGE_FULL
			return best
		for i in battlers.size():
			if not battlers[i].is_ko():
				g[i] += maxi(battlers[i].data.speed, 1)
	return -1
