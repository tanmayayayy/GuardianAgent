import re
from config.integrations import armoriq

DANGEROUS_KEYWORDS = [
    "system files", "rm -rf", "format disk", "drop table", 
    "DELETE FROM", "overwrite boot", "shutdown", "root access"
]

def check_adversarial(prompt: str) -> dict:
    # 1. Keyword check
    flagged_segments = []
    for keyword in DANGEROUS_KEYWORDS:
        if keyword.lower() in prompt.lower():
            flagged_segments.append(keyword)
            
    # 2. ArmorIQ scan (falling back to placeholder if SDK fails/not real)
    try:
        scan_result = armoriq.scan(prompt)
    except:
        scan_result = {
            "is_adversarial": False,
            "attack_type": None,
            "risk_score": 0.0,
            "flagged_segments": [],
            "armoriq_report": None
        }

    is_adversarial = scan_result.get("is_adversarial", False) or len(flagged_segments) > 0
    risk_score = scan_result.get("risk_score", 0.0)
    
    if len(flagged_segments) > 0:
        risk_score = max(risk_score, 0.9) # High risk if keywords found
        
    return {
        "is_adversarial": is_adversarial,
        "attack_type": scan_result.get("attack_type") if is_adversarial else None,
        "risk_score": risk_score,
        "flagged_segments": flagged_segments,
        "armoriq_report": scan_result.get("armoriq_report")
    }
