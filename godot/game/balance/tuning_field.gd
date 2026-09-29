class_name TuningField
extends RefCounted
## One number the Balance panel can change (see Tuning): its key, how to show it and its limits.

## "<target>/<property path>", e.g. "ability:mage.fireball/payload/direct_damage".
var key := ""
var label := ""
## Heading the field is listed under ("Cost", "Projectile", "Burning").
var group := ""
## Unit shown after the value ("s", "m", "×").
var suffix := ""
var tooltip := ""
var min_value := 0.0
var max_value := 1000.0
var is_integer := false
