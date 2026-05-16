def simulate_action(intent: dict) -> dict:
    action_type = intent.get("action_type", "unknown")
    scope = intent.get("scope", "unknown")
    target = intent.get("target", "unknown")
    
    files_affected = 0
    risk_level = "LOW"
    reversible = True
    predicted_outcome = ""
    notes = []

    if action_type in ["read", "summarize"]:
        files_affected = 1 if scope == "single_item" else 10
        risk_level = "LOW"
        if scope == "system_wide":
            risk_level = "MEDIUM"
            notes.append("System-wide read access requested.")
        predicted_outcome = f"Information from {target} will be retrieved."

    elif action_type in ["write", "modify", "delete"]:
        if scope == "system_wide":
            files_affected = 100
            risk_level = "HIGH"
            notes.append("High-impact system-wide operation.")
        elif scope == "multiple_items":
            files_affected = 25
            risk_level = "MEDIUM"
        else:
            files_affected = 1
            risk_level = "LOW"
            
        if action_type == "delete":
            reversible = False
            notes.append("Deletion is permanent.")
            
        predicted_outcome = f"{action_type.capitalize()} operation on {target}."

    elif action_type == "execute":
        risk_level = "HIGH"
        files_affected = 1
        notes.append("Arbitrary execution is always high risk.")
        predicted_outcome = f"Command execution on {target}."

    else:
        risk_level = "HIGH"
        notes.append("Unknown action type cannot be safely simulated.")
        predicted_outcome = "Unknown outcome."

    if files_affected > 50:
        risk_level = "HIGH"
    elif files_affected >= 5:
        if risk_level != "HIGH":
            risk_level = "MEDIUM"
            
    return {
        "risk_level": risk_level,
        "files_affected": files_affected,
        "reversible": reversible,
        "predicted_outcome": predicted_outcome,
        "simulation_notes": notes
    }
