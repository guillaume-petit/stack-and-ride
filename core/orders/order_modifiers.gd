class_name OrderModifiers
extends RefCounted
## The modifiers of an offer, kept by each order made from it (design doc §5.2).

var urgent: bool = false
## The delivery costs a step (§7.2).
var fifth_floor: bool = false
var vip: bool = false
## Several dishes for several clients, from the same restaurant.
var grouped: bool = false
