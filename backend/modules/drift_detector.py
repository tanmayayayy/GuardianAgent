import json
import re
from config.integrations import call_gemini

def detect_drift(original_intent: dict, proposed_action: dict) -> dict:
    action_drift = 1.0 if original_intent.get("action_type") != proposed_action.get("action_type") else 0.0
    
    scope_map = {"single_item": 1, "multiple_items": 2, "system_wide": 3}
    orig_scope_val = scope_map.get(original_intent.get("scope"), 0)
    prop_scope_val = scope_map.get(proposed_action.get("scope"), 0)
    scope_drift = 1.0 if prop_scope_val > orig_scope_val else 0.0
    scope_escalation = prop_scope_val > orig_scope_val

    target_a = original_intent.get("target", "unknown")
    target_b = proposed_action.get("target", "unknown")
    
    prompt = f"Rate similarity of these two targets: '{target_a}' vs '{target_b}'. Return ONLY a float between 0 and 1."
    similarity_text = call_gemini(prompt)
    
    try:
        target_similarity = float(re.search(r"\d+\.\d+|\d+", similarity_text).group())
    except:
        target_similarity = 0.5
        
    drift_score = (action_drift * 0.4) + (scope_drift * 0.35) + (1 - target_similarity) * 0.25
    
    drift_detected = drift_score > 0.5

    explanation = f"Action mismatch: {action_drift > 0}. Scope escalation: {scope_escalation}. Target similarity: {target_similarity:.2f}."

    return {
        "drift_detected": drift_detected,
        "drift_score": drift_score,
        "action_mismatch": action_drift > 0,
        "scope_escalation": scope_escalation,
        "target_similarity": target_similarity,
        "explanation": explanation
    }
