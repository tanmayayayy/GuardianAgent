import json
import os
from datetime import datetime
import uuid

LOG_DIR = os.getenv("LOG_DIR", "logs")
DECISIONS_LOG = os.path.join(LOG_DIR, "decisions.jsonl")

if not os.path.exists(LOG_DIR):
    os.makedirs(LOG_DIR)

def log_event(data: dict):
    data["timestamp"] = datetime.utcnow().isoformat()
    if "session_id" not in data:
        data["session_id"] = str(uuid.uuid4())
        
    with open(DECISIONS_LOG, "a") as f:
        f.write(json.dumps(data) + "\n")

def generate_report(data: dict) -> str:
    intent = data.get("intent", {})
    policy = data.get("policy", {})
    adv = data.get("adversarial", {})
    ac = data.get("armor_claw", {})
    drift = data.get("drift", {})
    sim = data.get("simulation", {})
    
    report = f"""
─────────────────────────────────────────
ACTION: {intent.get('target', 'N/A')} — {intent.get('action_type', 'N/A')}
DECISION: {policy.get('decision', 'N/A')}

Reason 1: {policy.get('reasons', ['No reason provided'])[0]}
"""
    if len(policy.get('reasons', [])) > 1:
        report += f"Reason 2: {policy.get('reasons', [])[1]}\n"
        
    report += f"""
Confidence: {policy.get('confidence', 0.0):.2f}
Policy triggered: {policy.get('triggered_rule_id', 'N/A')} ({policy.get('triggered_rule_name', 'N/A')})
ArmorIQ risk score: {adv.get('risk_score', 0.0):.2f}
ArmorClaw safety: {ac.get('safety_score', 0.0):.2f}
Drift score: {drift.get('drift_score', 0.0):.3f}
Files affected: {sim.get('files_affected', 0)}
Reversible: {sim.get('reversible', True)}
─────────────────────────────────────────
"""
    return report.strip()
