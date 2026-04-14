import os
import uuid
import json
from fastapi import FastAPI, Request, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional, List

from modules.intent_extractor import extract_intent
from modules.adversarial_defender import check_adversarial
from modules.drift_detector import detect_drift
from modules.action_simulator import simulate_action
from modules.policy_engine import evaluate_policy
from modules.executor import execute_action
from modules.logger import log_event, generate_report
from modules.armor_claw_defender import evaluate_armor_claw

app = FastAPI(title="Guardian Agent API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class EvaluateRequest(BaseModel):
    prompt: str
    session_id: Optional[str] = None

@app.middleware("http")
async def add_request_id(request: Request, call_next):
    request_id = str(uuid.uuid4())
    request.state.request_id = request_id
    response = await call_next(request)
    response.headers["X-Request-ID"] = request_id
    return response

@app.post("/evaluate")
async def evaluate(req: EvaluateRequest):
    session_id = req.session_id or str(uuid.uuid4())
    
    # 1. Intent Extraction
    intent = extract_intent(req.prompt)
    
    # 2. Adversarial Defense
    adversarial = check_adversarial(req.prompt)
    
    # 2.5 ArmorClaw Validation
    armor_claw_validation = evaluate_armor_claw(intent)
    
    # 3. Simulation
    simulation = simulate_action(intent)
    
    # 4. Drift (For this demo, we use extracted intent as proposed action, but in real flow proposed_action comes from LLM agent)
    # We'll simulate a slight variation to show drift logic if needed, but for now we compare intent to itself or a mock
    drift = detect_drift(intent, intent) 
    
    # 5. Policy Evaluation
    context = {
        "intent": intent,
        "adversarial": adversarial,
        "armor_claw": armor_claw_validation,
        "simulation": simulation,
        "drift": drift
    }
    policy = evaluate_policy(context)
    
    # 6. Execution
    execution = execute_action(policy["decision"], intent)
    
    # 7. Logging & Reporting
    report = generate_report({
        "intent": intent,
        "adversarial": adversarial,
        "armor_claw": armor_claw_validation,
        "simulation": simulation,
        "drift": drift,
        "policy": policy,
        "execution": execution
    })
    
    log_data = {
        "session_id": session_id,
        "raw_prompt": req.prompt,
        "intent": intent,
        "adversarial": adversarial,
        "armor_claw": armor_claw_validation,
        "drift": drift,
        "simulation": simulation,
        "policy": policy,
        "execution": execution
    }
    log_event(log_data)
    
    return {
        "decision": policy["decision"],
        "explainability_report": report,
        "intent": intent,
        "adversarial": adversarial,
        "armor_claw": armor_claw_validation,
        "drift": drift,
        "simulation": simulation,
        "policy": policy,
        "execution": execution
    }

@app.get("/logs")
async def get_logs():
    logs = []
    log_path = os.path.join(os.getenv("LOG_DIR", "logs"), "decisions.jsonl")
    if os.path.exists(log_path):
        with open(log_path, "r") as f:
            for line in f:
                logs.append(json.loads(line))
    return logs[::-1] # Newest first

@app.get("/policies")
async def get_policies():
    path = os.getenv("POLICIES_PATH", "policies.json")
    if os.path.exists(path):
        with open(path, "r") as f:
            return json.load(f)
    return {"rules": []}

@app.post("/policies")
async def update_policies(policies: dict):
    path = os.getenv("POLICIES_PATH", "policies.json")
    with open(path, "w") as f:
        json.dump(policies, f, indent=2)
    return {"status": "updated"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
