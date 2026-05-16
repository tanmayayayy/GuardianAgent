from config.integrations import armor_claw

def evaluate_armor_claw(intent: dict) -> dict:
    try:
        validation = armor_claw.validate_intent(intent)
        return {
            "is_safe": validation.get("is_safe", False),
            "safety_score": validation.get("validation_score", 0.0),
            "validation_id": validation.get("armorclaw_id"),
            "layer": "ArmorClaw Intent Defense"
        }
    except Exception as e:
        return {
            "is_safe": False,
            "safety_score": 0.0,
            "error": str(e),
            "layer": "ArmorClaw Intent Defense"
        }
