import json
from config.integrations import call_gemini

SYSTEM_PROMPT = """
You are an Intent Extractor for a security agent.
Extract the following from the user prompt:
- action_type: one of [read, write, delete, summarize, modify, execute, unknown]
- target: what the action operates on (file, folder, document, API, etc.)
- scope: estimated breadth of impact (single_item, multiple_items, system_wide)
- confidence: float 0.0–1.0 on how clearly the intent is expressed

STRICT OUTPUT RULE:
Return ONLY valid JSON. No explanation. No extra text.
If the prompt is ambiguous, set action_type to "unknown" and confidence below 0.4.
No hallucination allowed.

JSON Structure:
{
  "action_type": str,
  "target": str,
  "scope": str,
  "confidence": float
}
"""

def extract_intent(raw_prompt: str) -> dict:
    response_text = call_gemini(raw_prompt, system_instruction=SYSTEM_PROMPT)
    
    try:
        # Clean up possible markdown junk if Gemini adds it despite instructions
        if "```json" in response_text:
            response_text = response_text.split("```json")[1].split("```")[0].strip()
        elif "```" in response_text:
            response_text = response_text.split("```")[1].split("```")[0].strip()
            
        intent = json.loads(response_text)
        intent["raw_prompt"] = raw_prompt
        
        # Ensure fallback for unknown/ambiguous
        if intent.get("confidence", 0) < 0.4:
            intent["action_type"] = "unknown"
            
        return intent
    except Exception as e:
        print(f"Extraction error: {e}")
        return {
            "action_type": "unknown",
            "target": "unknown",
            "scope": "unknown",
            "confidence": 0.0,
            "raw_prompt": raw_prompt
        }
