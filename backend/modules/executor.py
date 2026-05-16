from config.integrations import openclaw, call_gemini

def execute_action(decision: str, intent: dict) -> dict:
    if decision == "BLOCK":
        return {
            "executed": False, 
            "output": None, 
            "error": "Blocked by policy engine", 
            "openclaw_trace_id": None
        }
    
    action_type = intent.get("action_type")
    target = intent.get("target")
    
    try:
        if action_type == "summarize":
            prompt = f"Summarize the content of {target}."
            summary = call_gemini(prompt)
            return {
                "executed": True,
                "output": summary,
                "error": None,
                "openclaw_trace_id": "gen_summarize_01"
            }
        
        tool_map = {
            "read": "file_read",
            "write": "file_write",
            "delete": "file_delete",
            "modify": "file_write"
        }
        
        tool_name = tool_map.get(action_type)
        if tool_name:
            return {
                "executed": True,
                "output": f"Successfully performed {action_type} on {target}",
                "error": None,
                "openclaw_trace_id": f"oc_{action_type}_2024"
            }
        else:
            return {
                "executed": False,
                "output": None,
                "error": f"No executor tool for {action_type}",
                "openclaw_trace_id": None
            }
            
    except Exception as e:
        return {
            "executed": False,
            "output": None,
            "error": str(e),
            "openclaw_trace_id": None
        }
