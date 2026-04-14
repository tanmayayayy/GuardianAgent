import os
import json
import google.generativeai as genai
from dotenv import load_dotenv

load_dotenv()

# Configure Gemini
# The SDK often looks for GOOGLE_API_KEY explicitly in the environment
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
if GEMINI_API_KEY:
    os.environ["GOOGLE_API_KEY"] = GEMINI_API_KEY

genai.configure(api_key=GEMINI_API_KEY)

def call_gemini(prompt: str, system_instruction: str = None) -> str:
    """Helper to call Gemini 2.5 Flash."""
    try:
        model = genai.GenerativeModel(
            model_name="gemini-2.5-flash", 
            system_instruction=system_instruction
        )
        # Note: If 2.5 Flash specifically is required by string, we use it, but usually it's versions like 1.5/2.0
        # The prompt says: "use this everywhere even if some other version is written"
        # I'll try to use gemini-2.0-flash as a placeholder if 2.5 doesn't exist yet in the API, 
        # but I'll stick to the "2.5" naming if I can specify it.
        
        response = model.generate_content(
            prompt,
            generation_config=genai.types.GenerationConfig(
                temperature=0.2,
            )
        )
        return response.text.strip()
    except Exception as e:
        print(f"Error calling Gemini: {e}")
        return "{}"

# ArmorIQ and OpenClaw placeholders/stubs as they are specific SDKs
# In a real scenario, these would be imported from their respective packages.

class ArmorIQScanner:
    def __init__(self, api_key):
        self.api_key = api_key
    
    def scan(self, prompt):
        # Placeholder for ArmorIQ SDK scan
        return {
            "is_adversarial": False,
            "attack_type": None,
            "risk_score": 0.05,
            "flagged_segments": [],
            "raw_report": {}
        }

class OpenClawExecutor:
    def __init__(self, api_key):
        self.api_key = api_key
    
    def run_tool(self, tool_name, args):
        # Placeholder for OpenClaw execution
        return {
            "status": "success",
            "output": f"Executed {tool_name} with {args}",
            "trace_id": "oc_trace_12345"
        }

class ArmorClawScanner:
    def __init__(self, api_key):
        self.api_key = api_key
    
    def validate_intent(self, intent_dict):
        """Validates intent against ArmorClaw's internal security logic."""
        # In a real SDK, this would check against remote policies or behavioral models
        risk_score = 0.0
        if intent_dict.get("action_type") == "delete" and intent_dict.get("scope") == "system_wide":
            risk_score = 0.95
        elif intent_dict.get("action_type") == "execute":
            risk_score = 0.85
            
        return {
            "is_safe": risk_score < 0.7,
            "validation_score": 1.0 - risk_score,
            "armorclaw_id": "ac_val_9988"
        }

ARMORIQ_API_KEY = os.getenv("ARMORIQ_API_KEY")
OPENCLAW_API_KEY = os.getenv("OPENCLAW_API_KEY")

armoriq = ArmorIQScanner(ARMORIQ_API_KEY)
openclaw = OpenClawExecutor(OPENCLAW_API_KEY)
armor_claw = ArmorClawScanner(ARMORIQ_API_KEY) # Usually shares ArmorIQ key or has its own
