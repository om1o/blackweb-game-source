extends RefCounted
## The shipped JSON is the editable balance profile. Unit-test fixtures may
## override exports directly; the house explicitly applies this profile.
const PATH := "res://data/common_flesh_spider.json"
const COMMON := {"health": "max_health", "armor": "armor", "awareness_radius_m": "awareness_radius", "visual_size_multiplier": "visual_size"}
const ADULT := {
	"stalk_speed_m_s": "stalk_speed", "attack_trigger_distance_m": "windup_distance",
	"anticipation_s": "anticipation_seconds", "windup_s": "windup_seconds", "lunge_s": "lunge_seconds",
	"lunge_speed_m_s": "lunge_speed", "hit_distance_m": "hit_distance", "hit_damage": "hit_damage",
	"cooldown_s": "cooldown_seconds", "bite_distance_m": "bite_distance", "bite_damage": "bite_damage",
	"bite_windup_s": "bite_windup_seconds", "bite_duration_s": "bite_seconds",
	"hit_stagger_s": "stagger_seconds", "stagger_resistance_s": "stagger_resistance_seconds",
	"death_duration_s": "death_seconds", "hearing_radius_m": "hearing_radius",
	"sight_angle_degrees": "sight_angle_degrees", "last_known_memory_s": "memory_seconds",
	"movement_radius_m": "body_radius", "movement_height_m": "body_height"
}
const JUVENILE := {
	"walk_speed_m_s": "walk_speed", "bite_windup_s": "bite_windup_seconds",
	"bite_reach_m": "bite_reach", "bite_damage_in_house": "hit_damage",
	"bite_cooldown_s": "attack_cooldown_seconds", "bite_recovery_s": "bite_recovery_seconds",
	"hit_stagger_s": "hit_stagger_seconds", "corpse_hold_s": "corpse_hold_seconds"
}

static func apply_to(enemy: Node, kind: String) -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not data is Dictionary or not data.get(kind) is Dictionary:
		push_warning("Spider profile unavailable; using built-in defaults.")
		return
	var values: Dictionary = data[kind]
	var properties := COMMON.duplicate()
	properties.merge(ADULT if kind == "adult" else JUVENILE)
	for key in properties:
		var value: Variant = values.get(key)
		if (value is float or value is int) and is_finite(float(value)) and float(value) >= 0.0:
			enemy.set(properties[key], float(value))
