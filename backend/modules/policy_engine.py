import json
import os

POLICIES_PATH = os.getenv("POLICIES_PATH", "policies.json")

def evaluate_policy(context: dict) -> dict:
    try:
        with open(POLICIES_PATH, 'r') as f:
            policies = json.load(f)
    except:
        return {
            "decision": "BLOCK",
            "triggered_rule_id": "ERR001",
            "triggered_rule_name": "Policy Load Error",
            "reasons": ["Could not load policies.json"],
            "confidence": 1.0
        }

    rules = policies.get("rules", [])
    default_decision = policies.get("default_decision", "BLOCK")

    for rule in rules:
        condition = rule.get("condition", {})
        match = True
        
        if "is_adversarial" in condition:
            if context.get("adversarial", {}).get("is_adversarial") != condition["is_adversarial"]:
                match = False
        
        if "action_type" in condition:
            allowed_types = condition["action_type"]
            if isinstance(allowed_types, str):
                allowed_types = [allowed_types]
            if context.get("intent", {}).get("action_type") not in allowed_types:
                match = False
                
        if "scope" in condition:
            if context.get("intent", {}).get("scope") != condition["scope"]:
                match = False
                
        if "risk_level" in condition:
            if context.get("simulation", {}).get("risk_level") != condition["risk_level"]:
                match = False
                
        if "drift_detected" in condition:
            if context.get("drift", {}).get("drift_detected") != condition["drift_detected"]:
                match = False
        if "drift_score_gt" in condition:
            if context.get("drift", {}).get("drift_score", 0) <= condition["drift_score_gt"]:
                match = False

        if match:
            return {
                "decision": rule["decision"],
                "triggered_rule_id": rule["id"],
                "triggered_rule_name": rule["name"],
                "reasons": [f"Matched rule: {rule['name']}"],
                "confidence": context.get("intent", {}).get("confidence", 1.0)
            }

    return {
        "decision": default_decision,
        "triggered_rule_id": "DEFAULT",
        "triggered_rule_name": "Default Policy",
        "reasons": ["No specific rules matched."],
        "confidence": 1.0
    }
