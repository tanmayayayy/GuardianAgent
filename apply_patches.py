import os
import re

base_dir = r"c:\Users\tanma\Tanmay\Projects\GuardianAgent\openclaw-framework"

def patch_file(rel_path, patches):
    path = os.path.join(base_dir, rel_path)
    if not os.path.exists(path):
        print(f"Skipping {rel_path} (not found)")
        return
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()
    
    modified = False
    for old, new in patches:
        if old in content:
            content = content.replace(old, new)
            modified = True
    
    if modified:
        with open(path, "w", encoding="utf-8") as f:
            f.write(content)
        print(f"Patched {rel_path}")
    else:
        print(f"No changes for {rel_path}")

# Patch 1: src/plugins/types.ts
# Extending context types
patch_file("src/plugins/types.ts", [
    (
        "export type PluginHookAgentContext = {",
        "export type PluginHookAgentContext = {\n  agentId?: string;\n  sessionKey?: string;\n  sessionId?: string;\n  workspaceDir?: string;\n  messageProvider?: string;\n  trigger?: string;\n  channelId?: string;\n  messageChannel?: string;\n  accountId?: string;\n  senderId?: string;\n  senderName?: string;\n  senderUsername?: string;\n  senderE164?: string;\n  runId?: string;\n  model?: unknown;\n  modelRegistry?: unknown;"
    ),
    (
        "export type PluginHookToolContext = {",
        "export type PluginHookToolContext = {\n  agentId?: string;\n  sessionKey?: string;\n  sessionId?: string;\n  toolName: string;\n  toolCallId?: string;\n  senderId?: string;\n  senderName?: string;\n  senderUsername?: string;\n  senderE164?: string;\n  runId?: string;\n  intentTokenRaw?: string;\n  csrgPath?: string;"
    )
])

# Patch 2: Passing context in attempt.ts
patch_file("src/agents/pi-embedded-runner/run/attempt.ts", [
    (
        "trigger: params.trigger,",
        "trigger: params.trigger,\n          channelId: params.messageChannel ?? params.messageProvider ?? undefined,\n          messageChannel: params.messageChannel ?? undefined,\n          accountId: params.agentAccountId ?? undefined,\n          senderId: params.senderId ?? undefined,\n          senderName: params.senderName ?? undefined,\n          senderUsername: params.senderUsername ?? undefined,\n          senderE164: params.senderE164 ?? undefined,\n          runId: params.runId,\n          model: params.model,\n          modelRegistry: params.modelRegistry,"
    )
])

print("Manual patching complete.")
