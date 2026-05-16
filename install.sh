#!/bin/bash
set -euo pipefail


R='\033[1;31m'
DR='\033[0;31m'
W='\033[1;97m'
D='\033[0;90m'
G='\033[32m'
N='\033[0m'
CYAN='\033[38;2;0;229;204m'
AMBER='\033[38;2;255;176;32m'
MUTED='\033[38;2;90;100;128m'
BOLD='\033[1m'

GUM=""
GUM_VERSION="0.17.0"
TMPFILES=()

TAGLINES=(
  "Your AI agents called. They want guardrails."
  "Because 'trust me bro' is not a security policy."
  "We armor the IQ so the AI doesn't go AWOL."
  "Zero-trust for agents. Zero chill for threats."
  "If your agent can delete prod, you need ArmorIQ."
  "Like a bouncer for your AI, but smarter."
  "Drift happens. We catch it before it ships."
  "Your policy engine called. It's lonely without you."
  "Agents move fast. ArmorIQ moves faster."
  "Sleep better knowing your agents can't go rogue."
  "Intent verified. Risk mitigated. Coffee earned."
  "Making 'AI safety' more than a buzzword since 2025."
  "Your compliance team will finally sleep at night."
  "Ctrl+Z for AI decisions you didn't authorize."
  "Because every good agent deserves a handler."
  "Policy enforcement at the speed of inference."
  "We read the agent's intent so you don't have to."
  "The guardrail your AI didn't know it needed."
  "Security that scales with your ambition."
  "Armor up. Ship out. Stay safe."
)

VALENTINE_TAGLINES=(
  "Guard your agents like you guard your heart."
  "Roses are red, policies are tight, ArmorIQ keeps your agents right."
  "Your agents love you. ArmorIQ makes sure they show it safely."
)

COMPLETION_MESSAGES=(
  "Locked and loaded. Your agents just got armored."
  "All set. Go build something wild, we'll keep it safe."
  "ArmorIQ is watching. In a good way. Not creepy."
  "Policy engine primed. Time to let the agents loose."
  "Your AI just got a security clearance upgrade."
  "Setup complete. Your future self thanks you."
  "Hardened. Verified. Ready to roll."
  "The shield is up. Send in the agents."
  "Consider your AI officially supervised."
  "Welcome to the armored side."
)

pick_tagline() {
  local month day
  month="$(date +%m)"
  day="$(date +%d)"
  if [[ "$month" == "02" && "$day" == "14" ]]; then
    echo "${VALENTINE_TAGLINES[RANDOM % ${#VALENTINE_TAGLINES[@]}]}"
    return
  fi
  echo "${TAGLINES[RANDOM % ${#TAGLINES[@]}]}"
}

pick_completion_message() {
  echo "${COMPLETION_MESSAGES[RANDOM % ${#COMPLETION_MESSAGES[@]}]}"
}

ARMORIQ_OC_VERSION=""
ARMORIQ_PLUGIN_VERSION=""
ARMORIQ_INSTALL_DIR=""
ARMORIQ_API_KEY=""
ARMORIQ_MODEL="${ARMORIQ_MODEL:-}"
ARMORIQ_OPENAI_KEY="${ARMORIQ_OPENAI_KEY:-}"
ARMORIQ_OPENROUTER_KEY="${ARMORIQ_OPENROUTER_KEY:-}"
ARMORIQ_ANTHROPIC_KEY="${ARMORIQ_ANTHROPIC_KEY:-}"
ARMORIQ_TELEGRAM_TOKEN="${ARMORIQ_TELEGRAM_TOKEN:-}"
ARMORIQ_TELEGRAM_DM_POLICY="${ARMORIQ_TELEGRAM_DM_POLICY:-open}"
ARMORIQ_TELEGRAM_STREAM_MODE="${ARMORIQ_TELEGRAM_STREAM_MODE:-partial}"
ARMORIQ_SLACK_BOT_TOKEN="${ARMORIQ_SLACK_BOT_TOKEN:-}"
ARMORIQ_GEMINI_KEY="${ARMORIQ_GEMINI_KEY:-}"
ARMORIQ_SKIP_KEY=false
ARMORIQ_NO_PROMPT=false
ARMORIQ_VERBOSE=false
ARMORIQ_DRY_RUN=false
ARMORIQ_SKIP_BUILD=false
OS="unknown"
INSTALL_STAGE_TOTAL=7
INSTALL_STAGE_CURRENT=0

cleanup_tmpfiles() {
  local f
  for f in "${TMPFILES[@]:-}"; do
    rm -rf "$f" 2>/dev/null || true
  done
}
trap cleanup_tmpfiles EXIT

mktempfile() {
  local f; f="$(mktemp)"; TMPFILES+=("$f"); echo "$f"
}


ui_info() {
  if [[ -n "$GUM" ]]; then
    "$GUM" log --level info "$*"
  else
    echo -e "${MUTED}·${N} $*"
  fi
}

ui_warn() {
  if [[ -n "$GUM" ]]; then
    "$GUM" log --level warn "$*"
  else
    echo -e "${AMBER}!${N} $*"
  fi
}

ui_success() {
  if [[ -n "$GUM" ]]; then
    local mark; mark="$("$GUM" style --foreground "#00e5cc" --bold "✓")"
    echo "${mark} $*"
  else
    echo -e "${CYAN}✓${N} $*"
  fi
}

ui_error() {
  if [[ -n "$GUM" ]]; then
    "$GUM" log --level error "$*"
  else
    echo -e "${R}✗${N} $*"
  fi
}

ui_section() {
  if [[ -n "$GUM" ]]; then
    "$GUM" style --bold --foreground "#ff4d4d" --padding "1 0" "$1"
  else
    echo ""
    echo -e "${R}${BOLD}$1${N}"
  fi
}

ui_stage() {
  INSTALL_STAGE_CURRENT=$((INSTALL_STAGE_CURRENT + 1))
  ui_section "[${INSTALL_STAGE_CURRENT}/${INSTALL_STAGE_TOTAL}] $1"
}

ui_kv() {
  local key="$1" value="$2"
  if [[ -n "$GUM" ]]; then
    local kp vp
    kp="$("$GUM" style --foreground "#5a6480" --width 22 "$key")"
    vp="$("$GUM" style --bold "$value")"
    "$GUM" join --horizontal "$kp" "$vp"
  else
    echo -e "  ${MUTED}${key}:${N} ${value}"
  fi
}

ui_panel() {
  if [[ -n "$GUM" ]]; then
    "$GUM" style --border rounded --border-foreground "#5a6480" --padding "0 1" "$1"
  else
    echo "$1"
  fi
}

ui_celebrate() {
  if [[ -n "$GUM" ]]; then
    "$GUM" style --bold --foreground "#00e5cc" "$1"
  else
    echo -e "${CYAN}${BOLD}$1${N}"
  fi
}

is_promptable() {
  [[ "$ARMORIQ_NO_PROMPT" != "true" ]] && [[ -r /dev/tty && -w /dev/tty ]]
}

run_with_spinner() {
  local title="$1"; shift
  if [[ -n "$GUM" ]] && [[ -t 2 || -t 1 ]]; then
    "$GUM" spin --spinner dot --title "$title" -- "$@"
    return $?
  fi
  "$@"
}

run_quiet_step() {
  local title="$1"; shift
  if [[ "$ARMORIQ_VERBOSE" == "true" ]]; then
    run_with_spinner "$title" "$@"
    return $?
  fi
  local log; log="$(mktempfile)"
  if [[ -n "$GUM" ]] && [[ -t 2 || -t 1 ]]; then
    local cmd_quoted="" log_quoted=""
    printf -v cmd_quoted '%q ' "$@"
    printf -v log_quoted '%q' "$log"
    if run_with_spinner "$title" bash -c "${cmd_quoted}>${log_quoted} 2>&1"; then
      return 0
    fi
  else
    if "$@" >"$log" 2>&1; then
      return 0
    fi
  fi
  ui_error "${title} failed"
  if [[ -s "$log" ]]; then
    tail -n 40 "$log" >&2 || true
  fi
  return 1
}

prompt_input() {
  local prompt_text="$1"
  local result=""
  if [[ -n "$GUM" ]] && is_promptable; then
    result="$("$GUM" input --placeholder "$prompt_text" < /dev/tty)" || true
  elif is_promptable; then
    echo -en "  ${W}${prompt_text}: ${N}" >&2
    read -r result < /dev/tty
  fi
  echo "$result"
}

prompt_confirm() {
  local prompt_text="$1"
  if [[ -n "$GUM" ]] && is_promptable; then
    "$GUM" confirm "$prompt_text" < /dev/tty
    return $?
  elif is_promptable; then
    echo -en "  ${W}${prompt_text} (y/n): ${N}" >&2
    local answer
    read -r answer < /dev/tty
    [[ "$answer" =~ ^[Yy] ]]
    return $?
  fi
  return 1
}

prompt_choice() {
  local header="$1"; shift
  if [[ -n "$GUM" ]] && is_promptable; then
    "$GUM" choose --header "$header" "$@" < /dev/tty
    return $?
  elif is_promptable; then
    echo -e "  ${W}${header}${N}" >&2
    local i=1 opt
    for opt in "$@"; do
      echo -e "    ${i}) ${opt}" >&2
      i=$((i + 1))
    done
    echo -en "  ${W}Choice: ${N}" >&2
    local choice
    read -r choice < /dev/tty
    local idx=1
    for opt in "$@"; do
      if [[ "$idx" == "$choice" ]]; then
        echo "$opt"
        return 0
      fi
      idx=$((idx + 1))
    done
    echo "$1"
    return 0
  fi
  echo "$1"
  return 0
}


gum_detect_os() {
  case "$(uname -s 2>/dev/null || true)" in
    Darwin) echo "Darwin" ;; Linux) echo "Linux" ;; *) echo "unsupported" ;;
  esac
}

gum_detect_arch() {
  case "$(uname -m 2>/dev/null || true)" in
    x86_64|amd64) echo "x86_64" ;; arm64|aarch64) echo "arm64" ;;
    i386|i686) echo "i386" ;; *) echo "unknown" ;;
  esac
}

bootstrap_gum() {
  GUM=""
  if [[ "${ARMORIQ_NO_GUM:-}" == "1" ]]; then return 1; fi
  if [[ "${TERM:-dumb}" == "dumb" ]]; then return 1; fi
  if [[ ! -t 2 && ! -t 1 ]] && [[ ! -r /dev/tty || ! -w /dev/tty ]]; then return 1; fi

  if command -v gum >/dev/null 2>&1; then
    GUM="gum"; ui_success "gum available (system)"; return 0
  fi

  local os arch asset base gum_tmpdir gum_path
  os="$(gum_detect_os)"; arch="$(gum_detect_arch)"
  [[ "$os" == "unsupported" || "$arch" == "unknown" ]] && return 1

  asset="gum_${GUM_VERSION}_${os}_${arch}.tar.gz"
  base="https://github.com/charmbracelet/gum/releases/download/v${GUM_VERSION}"
  gum_tmpdir="$(mktemp -d)"; TMPFILES+=("$gum_tmpdir")

  if command -v curl &>/dev/null; then
    curl -fsSL -o "$gum_tmpdir/$asset" "${base}/${asset}" 2>/dev/null || return 1
  elif command -v wget &>/dev/null; then
    wget -q -O "$gum_tmpdir/$asset" "${base}/${asset}" 2>/dev/null || return 1
  else
    return 1
  fi

  tar -xzf "$gum_tmpdir/$asset" -C "$gum_tmpdir" >/dev/null 2>&1 || return 1
  gum_path="$(find "$gum_tmpdir" -type f -name gum 2>/dev/null | head -n1 || true)"
  [[ -z "$gum_path" ]] && return 1
  chmod +x "$gum_path" 2>/dev/null || true
  [[ ! -x "$gum_path" ]] && return 1

  GUM="$gum_path"
  ui_success "gum bootstrapped (v${GUM_VERSION})"
  return 0
}



print_banner() {
  clear 2>/dev/null || true
  sleep 0.1
  local tagline
  tagline="$(pick_tagline)"
echo ""
echo -e "${R}    ╔════════════════════════════════════════════════════════════╗${N}"
echo -e "${R}    ║${N}                                                            ${R}║${N}"
echo -e "${R}    ║${W}     ▄▀█ █▀█ █▀▄▀█ █▀█ █▀█ █▀▀ █   ▄▀█ █ █ █                ${N}${R}║${N}"
echo -e "${R}    ║${W}     █▀█ █▀▄ █ ▀ █ █▄█ █▀▄ █▄▄ █▄▄ █▀█ ▀▄▀▄▀                ${N}${R}║${N}"
echo -e "${R}    ║${N}                                                            ${R}║${N}"
echo -e "${R}    ║${D}      AI agents are moving fast. Security isn't.            ${N}${R}║${N}"
echo -e "${R}    ║${N}                                                            ${R}║${N}"
echo -e "${R}    ║${W}      The control layer for the agent era.                  ${N}${R}║${N}"
echo -e "${R}    ║${D}      Track intent. Catch drift. Stop risk.                 ${N}${R}║${N}"
echo -e "${R}    ║${N}                                                            ${R}║${N}"
echo -e "${R}    ║${DR}                   armoriq.ai                               ${N}${R}║${N}"
echo -e "${R}    ║${N}                                                            ${R}║${N}"
echo -e "${R}    ╚════════════════════════════════════════════════════════════╝${N}"
echo ""
sleep 0.8
}

print_footer() {
  echo ""
  echo -e "${R}  ╔═════════════════════════════════════════════════════════╗${N}"
  echo -e "${R}  ║                                                         ║${N}"
  echo -e "${R}  ║${W}  ✓ Setup complete. Lock it down.                        ${R}║${N}"
  echo -e "${R}  ║                                                         ║${N}"
  echo -e "${R}  ║${D}  → Start the gateway:                                   ${R}║${N}"
  echo -e "${R}  ║                                                         ║${N}"
  echo -e "${R}  ╚═════════════════════════════════════════════════════════╝${N}"
  echo ""
  echo -e "${D}  ┌─────────────────────────────────────────────────────────┐${N}"
  echo -e "${D}  │                                                         │${N}"
  echo -e "${D}  │${W}  \$ cd ${ARMORIQ_INSTALL_DIR}                                ${D}│${N}"
  echo -e "${D}  │${W}  \$ pnpm dev gateway                                     ${D}│${N}"
  echo -e "${D}  │                                                         │${N}"
  echo -e "${D}  └─────────────────────────────────────────────────────────┘${N}"
  echo ""
  echo -e "            ${DR}◉${N} ${W}https://armoriq.ai/${N} ${DR}◉${N}  "
  echo ""
}   

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --version)         ARMORIQ_OC_VERSION="$2"; shift 2 ;;
      --plugin-version)  ARMORIQ_PLUGIN_VERSION="$2"; shift 2 ;;
      --install-dir)     ARMORIQ_INSTALL_DIR="$2"; shift 2 ;;
      --api-key)         ARMORIQ_API_KEY="$2"; shift 2 ;;
      --skip-key)        ARMORIQ_SKIP_KEY=true; shift ;;
      --no-prompt)       ARMORIQ_NO_PROMPT=true; shift ;;
      --verbose)         ARMORIQ_VERBOSE=true; shift ;;
      --dry-run)         ARMORIQ_DRY_RUN=true; shift ;;
      --skip-build)      ARMORIQ_SKIP_BUILD=true; shift ;;
      --no-gum)          export ARMORIQ_NO_GUM=1; shift ;;
      --help|-h)
        echo "ArmorIQ OpenClaw Installer"
        echo ""
        echo "Usage: install-armoriq.sh [options]"
        echo ""
        echo "Options:"
        echo "  --version <ver>         OpenClaw version to install (default: latest)"
        echo "  --plugin-version <ver>  ArmorClaw plugin version to install (default: latest)"
        echo "  --install-dir <dir>     Where to clone OpenClaw (default: ~/openclaw-armoriq)"
        echo "  --api-key <key>         ArmorIQ API key"
        echo "  --model <model>         LLM model (e.g. openai/gpt-5.2, google/gemini-2.5-flash)"
        echo "  --openai-key <key>      OpenAI API key"
        echo "  --openrouter-key <key>  OpenRouter API key"
        echo "  --anthropic-key <key>   Anthropic API key"
        echo "  --gemini-key <key>      Google Gemini API key"
        echo "  --telegram-token <tok>  Telegram bot token"
        echo "  --telegram-dm-policy <p> DM policy: open|pairing|allowlist (default: open)"
        echo "  --telegram-stream <m>   Stream mode: partial|block|off (default: partial)"
        echo "  --slack-bot-token <tok> Slack bot token (xoxb-...)"
        echo "  --slack-app-token <tok> Slack app token (xapp-...)"
        echo "  --skip-key              Skip API key prompt"
        echo "  --skip-build            Skip pnpm install/build (if already built)"
        echo "  --no-prompt             Non-interactive mode"
        echo "  --verbose               Show command output"
        echo "  --dry-run               Show plan without executing"
        echo "  --no-gum                Disable gum TUI"
        echo "  --help                  Show this help"
        exit 0
        ;;
      --telegram-dm-policy) ARMORIQ_TELEGRAM_DM_POLICY="$2"; shift 2 ;;
      --telegram-stream)    ARMORIQ_TELEGRAM_STREAM_MODE="$2"; shift 2 ;;
      --gemini-key)         ARMORIQ_GEMINI_KEY="$2"; shift 2 ;;
      *) ui_error "Unknown option: $1"; exit 1 ;;
    esac
  done
}


detect_os() {
  if [[ "$OSTYPE" == "darwin"* ]]; then OS="macos"
  elif [[ "$OSTYPE" == "linux-gnu"* ]] || [[ -n "${WSL_DISTRO_NAME:-}" ]]; then OS="linux"
  elif [[ "$OSTYPE" == "msys"* ]] || [[ "$OSTYPE" == "mingw"* ]] || [[ "$OSTYPE" == "cygwin"* ]]; then OS="windows"
  else
    ui_error "Unsupported OS. Supported: macOS, Linux, Windows."
    exit 1
  fi
  ui_success "Detected: ${OS}"
}


check_command() {
  command -v "$1" &>/dev/null
}

ensure_node() {
  if check_command node; then
    local node_major
    node_major="$(node -v | sed 's/v//' | cut -d. -f1)"
    if [[ "$node_major" -ge 20 ]]; then
      ui_success "Node.js $(node -v)"
      return 0
    fi
    ui_warn "Node.js $(node -v) found but v20+ required"
  fi

  if [[ "$OS" == "macos" ]] && check_command brew; then
    run_quiet_step "Installing Node.js via Homebrew" brew install node
  elif [[ "$OS" == "linux" ]]; then
    if check_command apt-get; then
      run_quiet_step "Installing Node.js" sudo apt-get install -y nodejs npm
    elif check_command yum; then
      run_quiet_step "Installing Node.js" sudo yum install -y nodejs npm
    else
      ui_error "Install Node.js v20+ manually: https://nodejs.org"
      exit 1
    fi
  else
    ui_error "Install Node.js v20+ manually: https://nodejs.org"
    exit 1
  fi
  ui_success "Node.js installed"
}

ensure_git() {
  if check_command git; then
    ui_success "Git $(git --version | awk '{print $3}')"
    return 0
  fi
  if [[ "$OS" == "macos" ]]; then
    run_quiet_step "Installing Git" xcode-select --install 2>/dev/null || brew install git
  elif check_command apt-get; then
    run_quiet_step "Installing Git" sudo apt-get install -y git
  else
    ui_error "Install git manually"; exit 1
  fi
  ui_success "Git installed"
}

ensure_pnpm() {
  if check_command pnpm; then
    ui_success "pnpm $(pnpm --version)"
    return 0
  fi

  if check_command corepack; then
    run_quiet_step "Enabling pnpm via corepack" corepack enable pnpm
    if check_command pnpm; then
      ui_success "pnpm $(pnpm --version) via corepack"
      return 0
    fi
  fi

  run_quiet_step "Installing pnpm" npm install -g pnpm
  ui_success "pnpm installed"
}

ensure_python3() {
  if check_command python3; then
    ui_success "Python3 $(python3 --version | awk '{print $2}')"
    return 0
  fi
  if [[ "$OS" == "windows" ]] && check_command python; then
    local pyver
    pyver="$(python --version 2>&1 | awk '{print $2}')"
    if [[ "$pyver" == 3.* ]]; then
      python3() { python "$@"; }
      ui_success "Python3 ${pyver} (as 'python')"
      return 0
    fi
  fi
  if [[ "$OS" == "macos" ]] && check_command brew; then
    run_quiet_step "Installing Python3" brew install python3
  elif check_command apt-get; then
    run_quiet_step "Installing Python3" sudo apt-get install -y python3
  else
    ui_error "Install python3 manually (needed for patching)"; exit 1
  fi
  ui_success "Python3 installed"
}


resolve_latest_version() {
  echo "2026.3.2"
}

resolve_version() {
  if [[ -z "$ARMORIQ_OC_VERSION" ]]; then
    ARMORIQ_OC_VERSION="$(resolve_latest_version)"
    if [[ -z "$ARMORIQ_OC_VERSION" ]]; then
      ui_error "Could not resolve latest OpenClaw version from npm"
      exit 1
    fi
  fi
  ui_success "Target: OpenClaw v${ARMORIQ_OC_VERSION}"
}

clone_openclaw() {
  local dir="$ARMORIQ_INSTALL_DIR"
  local git_version="$ARMORIQ_OC_VERSION"
  if [[ "$git_version" =~ ^[0-9]{4}\.[0-9]+\.[0-9]+-[0-9]+$ ]]; then
    git_version="${git_version%-*}"
  fi
  local tag="v${git_version}"

  if [[ -d "$dir/.git" ]]; then
    local existing_ver
    existing_ver="$(node -e "console.log(require('${dir}/package.json').version)" 2>/dev/null || echo "")"
    if [[ "$existing_ver" == "$ARMORIQ_OC_VERSION" ]]; then
      ui_success "OpenClaw v${ARMORIQ_OC_VERSION} already cloned at ${dir}"
      return 0
    fi
    ui_warn "Existing clone is v${existing_ver}, expected v${ARMORIQ_OC_VERSION}"
    if is_promptable; then
      if prompt_confirm "Remove existing clone and re-clone?"; then
        rm -rf "$dir"
      else
        ui_info "Keeping existing clone"
        return 0
      fi
    else
      ui_info "Re-cloning to match target version"
      rm -rf "$dir"
    fi
  fi

  ui_info "Cloning OpenClaw ${tag} to ${dir}"
  run_quiet_step "Cloning OpenClaw" git clone --depth 1 --branch "$tag" \
    https://github.com/openclaw/openclaw.git "$dir"
  ui_success "Cloned OpenClaw ${tag}"
}




apply_patches() {
  local prev_dir="$PWD"
  cd "$ARMORIQ_INSTALL_DIR"

  local OC_VERSION=""
  if [[ -f "package.json" ]]; then
    OC_VERSION=$(node -e "console.log(require('./package.json').version)" 2>/dev/null || echo "unknown")
  fi

  if [[ -z "$OC_VERSION" ]] || [[ "$OC_VERSION" == "unknown" ]]; then
    ui_error "Cannot detect OpenClaw version from package.json"
    cd "$prev_dir"
    exit 1
  fi

  ui_info "OpenClaw v${OC_VERSION} detected"

  local total=10
  ui_info "Applying $total patches"

  local step=0
  patch_bar() {
    step=$((step + 1))
    local pct=$((step * 100 / total))
    local filled=$((pct / 5))
    local empty=$((20 - filled))
    printf "\r${R}  [${W}"
    for ((i=0; i<filled; i++)); do printf "█"; done
    for ((i=0; i<empty; i++)); do printf "${D}░"; done
    printf "${R}] ${W}%3d%%${N}  %s" "$pct" "$1"
    echo ""
  }

  local TYPES_FILE="src/plugins/types.ts"
  local ATTEMPT_FILE="src/agents/pi-embedded-runner/run/attempt.ts"
  local RUN_FILE="src/agents/pi-embedded-runner/run.ts"

  for f in "$TYPES_FILE" "$ATTEMPT_FILE" "$RUN_FILE"; do
    if [[ ! -f "$f" ]]; then
      ui_error "$f not found"
      cd "$prev_dir"
      exit 1
    fi
  done

  patch_bar "types.ts  PluginHookAgentContext"

  python3 << 'PYEOF'
import re
with open("src/plugins/types.ts", "r") as f:
    content = f.read()

idx = content.find("PluginHookAgentContext")
if idx != -1:
    snippet = content[idx:idx+600]
    if "messageChannel" in snippet and "model?" in snippet:
        print("  [skip] PluginHookAgentContext already extended")
    else:
        m = re.search(r'export type PluginHookAgentContext = \{[^}]+\};', content, re.DOTALL)
        if m:
            new_ctx = """export type PluginHookAgentContext = {
  agentId?: string;
  sessionKey?: string;
  sessionId?: string;
  workspaceDir?: string;
  messageProvider?: string;
  trigger?: string;
  channelId?: string;
  messageChannel?: string;
  accountId?: string;
  senderId?: string;
  senderName?: string;
  senderUsername?: string;
  senderE164?: string;
  runId?: string;
  model?: unknown;
  modelRegistry?: unknown;
};"""
            content = content[:m.start()] + new_ctx + content[m.end():]
            with open("src/plugins/types.ts", "w") as f:
                f.write(content)
            print("  [patch] Extended PluginHookAgentContext")
        else:
            print("  [warn] PluginHookAgentContext structure changed")
else:
    print("  [skip] PluginHookAgentContext not found")
PYEOF

  patch_bar "types.ts  BeforeAgentStartEvent.tools"

  if grep -q 'tools?: Array<{' "$TYPES_FILE"; then
    echo -e "  ${D}[skip] already has tools${N}"
  else
    sed -i.bak '/^  messages?: unknown\[\];$/a\
\  tools?: Array<{\
\    name: string;\
\    description?: string;\
\    parameters?: Record<string, unknown>;\
\  }>;' "$TYPES_FILE"
    rm -f "${TYPES_FILE}.bak"
  fi

  patch_bar "attempt.ts  hookCtx sender/model"

  python3 << 'PYEOF'
with open("src/agents/pi-embedded-runner/run/attempt.ts", "r") as f:
    content = f.read()

if "senderId: params.senderId ?? undefined" in content and "model: params.model" in content:
    print("  [skip] attempt.ts hookCtx already patched")
else:
    old_v3x = """        const hookCtx = {
          agentId: hookAgentId,
          sessionKey: params.sessionKey,
          sessionId: params.sessionId,
          workspaceDir: params.workspaceDir,
          messageProvider: params.messageProvider ?? undefined,
          trigger: params.trigger,
          channelId: params.messageChannel ?? params.messageProvider ?? undefined,
        };"""
    new_v3x = """        const hookCtx = {
          agentId: hookAgentId,
          sessionKey: params.sessionKey,
          sessionId: params.sessionId,
          workspaceDir: params.workspaceDir,
          messageProvider: params.messageProvider ?? undefined,
          trigger: params.trigger,
          channelId: params.messageChannel ?? params.messageProvider ?? undefined,
          messageChannel: params.messageChannel ?? undefined,
          accountId: params.agentAccountId ?? undefined,
          senderId: params.senderId ?? undefined,
          senderName: params.senderName ?? undefined,
          senderUsername: params.senderUsername ?? undefined,
          senderE164: params.senderE164 ?? undefined,
          runId: params.runId,
          model: params.model,
          modelRegistry: params.modelRegistry,
        };"""

    old_v19 = """        const hookCtx = {
          agentId: hookAgentId,
          sessionKey: params.sessionKey,
          sessionId: params.sessionId,
          workspaceDir: params.workspaceDir,
          messageProvider: params.messageProvider ?? undefined,
        };"""
    new_v19 = """        const hookCtx = {
          agentId: hookAgentId,
          sessionKey: params.sessionKey,
          sessionId: params.sessionId,
          workspaceDir: params.workspaceDir,
          messageProvider: params.messageProvider ?? undefined,
          messageChannel: params.messageChannel ?? undefined,
          accountId: params.agentAccountId ?? undefined,
          senderId: params.senderId ?? undefined,
          senderName: params.senderName ?? undefined,
          senderUsername: params.senderUsername ?? undefined,
          senderE164: params.senderE164 ?? undefined,
          runId: params.runId,
          model: params.model,
          modelRegistry: params.modelRegistry,
        };"""

    found = False
    if old_v3x in content:
        content = content.replace(old_v3x, new_v3x)
        found = True
        print("  [patch] attempt.ts hookCtx (v3x style)")
    elif old_v19 in content:
        content = content.replace(old_v19, new_v19)
        found = True
        print("  [patch] attempt.ts hookCtx (v19 style)")

    if found:
        with open("src/agents/pi-embedded-runner/run/attempt.ts", "w") as f:
            f.write(content)
    else:
        print("  [warn] Could not find hookCtx pattern in attempt.ts")
PYEOF

  patch_bar "attempt.ts  tools in hooks"

  python3 << 'PYEOF'
with open("src/agents/pi-embedded-runner/run/attempt.ts", "r") as f:
    content = f.read()

changed = False

old_runner_sig = 'event: { prompt: string; messages: unknown[] },\n    ctx: PluginHookAgentContext,\n  ) => Promise<PluginHookBeforeAgentStartResult | undefined>;'
new_runner_sig = 'event: { prompt: string; messages: unknown[]; tools?: Array<{ name: string; description?: string; parameters?: Record<string, unknown> }> },\n    ctx: PluginHookAgentContext,\n  ) => Promise<PluginHookBeforeAgentStartResult | undefined>;'

if new_runner_sig in content:
    print("  [skip] PromptBuildHookRunner already has tools")
elif old_runner_sig in content:
    content = content.replace(old_runner_sig, new_runner_sig)
    changed = True
    print("  [patch] PromptBuildHookRunner.runBeforeAgentStart tools added")

old_resolve_sig = """export async function resolvePromptBuildHookResult(params: {
  prompt: string;
  messages: unknown[];
  hookCtx: PluginHookAgentContext;"""
new_resolve_sig = """export async function resolvePromptBuildHookResult(params: {
  prompt: string;
  messages: unknown[];
  tools?: Array<{ name: string; description?: string; parameters?: Record<string, unknown> }>;
  hookCtx: PluginHookAgentContext;"""

if new_resolve_sig in content:
    print("  [skip] resolvePromptBuildHookResult already has tools param")
elif old_resolve_sig in content:
    content = content.replace(old_resolve_sig, new_resolve_sig)
    changed = True
    print("  [patch] resolvePromptBuildHookResult tools param added")

old_event_pass = ("          .runBeforeAgentStart(\n"
    "            {\n"
    "              prompt: params.prompt,\n"
    "              messages: params.messages,\n"
    "            },\n")
new_event_pass = ("          .runBeforeAgentStart(\n"
    "            {\n"
    "              prompt: params.prompt,\n"
    "              messages: params.messages,\n"
    "              tools: params.tools,\n"
    "            },\n")

if "tools: params.tools," in content and "before_agent_start hook (legacy" in content:
    print("  [skip] tools already passed in runBeforeAgentStart event")
elif old_event_pass in content:
    content = content.replace(old_event_pass, new_event_pass)
    changed = True
    print("  [patch] tools passed in runBeforeAgentStart event")

old_call = """        const hookResult = await resolvePromptBuildHookResult({
          prompt: params.prompt,
          messages: activeSession.messages,
          hookCtx,"""
new_call = """        const hookResult = await resolvePromptBuildHookResult({
          prompt: params.prompt,
          messages: activeSession.messages,
          tools: tools.map((t) => ({
            name: t.name ?? "",
            description: t.description,
            parameters: t.parameters as Record<string, unknown> | undefined,
          })),
          hookCtx,"""

if "tools: tools.map" in content and "resolvePromptBuildHookResult" in content:
    print("  [skip] tools already passed at call site")
elif old_call in content:
    content = content.replace(old_call, new_call)
    changed = True
    print("  [patch] tools passed at resolvePromptBuildHookResult call site")

if changed:
    with open("src/agents/pi-embedded-runner/run/attempt.ts", "w") as f:
        f.write(content)
PYEOF

  patch_bar "types.ts  PluginHookToolContext"

  python3 << 'PYEOF'
with open("src/plugins/types.ts", "r") as f:
    content = f.read()

import re
m = re.search(r'export type PluginHookToolContext = \{[^}]+\}', content)
if m:
    block = m.group(0)
    if "senderId" in block:
        print("  [skip] PluginHookToolContext already extended")
    else:
        new = """export type PluginHookToolContext = {
  agentId?: string;
  sessionKey?: string;
  sessionId?: string;
  toolName: string;
  toolCallId?: string;
  senderId?: string;
  senderName?: string;
  senderUsername?: string;
  senderE164?: string;
  runId?: string;
  intentTokenRaw?: string;
  csrgPath?: string;
}"""
        content = content.replace(block, new)
        with open("src/plugins/types.ts", "w") as f:
            f.write(content)
        print("  [patch] Extended PluginHookToolContext")
else:
    print("  [skip] PluginHookToolContext not found")
PYEOF

  patch_bar "before-tool-call.ts  HookContext + forwarding"

  python3 << 'PYEOF'
fpath = "src/agents/pi-tools.before-tool-call.ts"
try:
    with open(fpath, "r") as f:
        content = f.read()
except FileNotFoundError:
    print("  [skip] pi-tools.before-tool-call.ts not found")
    exit(0)

changed = False

import re
m = re.search(r'(?:export )?type HookContext = \{[^}]+\};', content)
if m:
    block = m.group(0)
    if "senderId" in block:
        print("  [skip] HookContext already extended")
    else:
        export_prefix = "export " if block.startswith("export ") else ""
        has_loop = "loopDetection" in block
        new_fields = []
        new_fields.append("  agentId?: string;")
        new_fields.append("  sessionKey?: string;")
        if has_loop:
            new_fields.append("  sessionId?: string;")
            new_fields.append("  loopDetection?: ToolLoopDetectionConfig;")
        new_fields.extend([
            "  senderId?: string;",
            "  senderName?: string;",
            "  senderUsername?: string;",
            "  senderE164?: string;",
            "  runId?: string;",
        ])
        new_type = export_prefix + "type HookContext = {\n" + "\n".join(new_fields) + "\n};"
        content = content.replace(block, new_type)
        changed = True
        print("  [patch] HookContext type extended")

if "senderId: args.ctx.senderId" in content:
    print("  [skip] context forwarding already patched")
else:
    import re
    run_id_spread = "...(args.ctx?.runId ? { runId: args.ctx.runId } : {}),"
    tool_call_spread = "...(args.toolCallId ? { toolCallId: args.toolCallId } : {}),"
    idx = content.find(run_id_spread)
    if idx != -1:
        eol = content.index("\n", idx)
        indent = "      "
        sender_lines = (
            indent + "...(args.ctx?.senderId ? { senderId: args.ctx.senderId } : {}),\n"
            + indent + "...(args.ctx?.senderName ? { senderName: args.ctx.senderName } : {}),\n"
            + indent + "...(args.ctx?.senderUsername ? { senderUsername: args.ctx.senderUsername } : {}),\n"
            + indent + "...(args.ctx?.senderE164 ? { senderE164: args.ctx.senderE164 } : {}),\n"
        )
        content = content[:eol+1] + sender_lines + content[eol+1:]
        changed = True
        print("  [patch] context forwarding extended (spread style)")
    else:
        old_pass = ("toolName,\n"
            "        agentId: args.ctx?.agentId,\n"
            "        sessionKey: args.ctx?.sessionKey,\n"
            "      },")
        new_pass = ("toolName,\n"
            "        agentId: args.ctx?.agentId,\n"
            "        sessionKey: args.ctx?.sessionKey,\n"
            "        senderId: args.ctx?.senderId,\n"
            "        senderName: args.ctx?.senderName,\n"
            "        senderUsername: args.ctx?.senderUsername,\n"
            "        senderE164: args.ctx?.senderE164,\n"
            "        runId: args.ctx?.runId,\n"
            "      },")
        if old_pass in content:
            content = content.replace(old_pass, new_pass)
            changed = True
            print("  [patch] context forwarding extended (old style)")
        else:
            print("  [warn] context forwarding pattern not found")

if changed:
    with open(fpath, "w") as f:
        f.write(content)
PYEOF

  patch_bar "pi-tools.ts  wrapToolWithBeforeToolCallHook"

  python3 << 'PYEOF'
import re
fpath = "src/agents/pi-tools.ts"
try:
    with open(fpath, "r") as f:
        content = f.read()
except FileNotFoundError:
    print("  [skip] pi-tools.ts not found")
    exit(0)

if "senderId: options?.senderId ?? undefined" in content:
    print("  [skip] wrapToolWithBeforeToolCallHook already extended")
else:
    lines = content.split("\n")
    insert_idx = None
    for i, line in enumerate(lines):
        if "wrapToolWithBeforeToolCallHook(tool, {" in line:
            depth = 0
            for j in range(i, min(i + 20, len(lines))):
                depth += lines[j].count("{") - lines[j].count("}")
                if depth == 0 and "})" in lines[j]:
                    insert_idx = j
                    break
            break
    if insert_idx is not None and "senderId" not in "\n".join(lines[insert_idx-6:insert_idx+1]):
        indent = "      "
        sender_lines = [
            indent + "senderId: options?.senderId ?? undefined,",
            indent + "senderName: options?.senderName ?? undefined,",
            indent + "senderUsername: options?.senderUsername ?? undefined,",
            indent + "senderE164: options?.senderE164 ?? undefined,",
        ]
        for sl in reversed(sender_lines):
            lines.insert(insert_idx, sl)
        content = "\n".join(lines)
        with open(fpath, "w") as f:
            f.write(content)
        print("  [patch] wrapToolWithBeforeToolCallHook extended")
    elif insert_idx is not None:
        print("  [skip] sender fields already in wrapToolWithBeforeToolCallHook")
    else:
        print("  [warn] wrapToolWithBeforeToolCallHook pattern not found")
PYEOF

  patch_bar "run.ts  hookCtx + model + no before_agent_start"

  python3 << 'PYEOF'
import re

fpath = "src/agents/pi-embedded-runner/run.ts"
with open(fpath, "r") as f:
    content = f.read()

changed = False

if "PluginHookAgentContext" not in content:
    old_import = 'import type { PluginHookBeforeAgentStartResult } from "../../plugins/types.js";'
    new_import = 'import type { PluginHookAgentContext, PluginHookBeforeAgentStartResult } from "../../plugins/types.js";'
    if old_import in content:
        content = content.replace(old_import, new_import)
        changed = True
        print("  [patch] Added PluginHookAgentContext import")
    else:
        print("  [warn] Could not find import line for PluginHookBeforeAgentStartResult")
else:
    print("  [skip] PluginHookAgentContext already imported")

if "const hookCtx: PluginHookAgentContext = {" in content:
    print("  [skip] hookCtx already typed")
elif "const hookCtx = {" in content:
    content = content.replace("const hookCtx = {", "const hookCtx: PluginHookAgentContext = {", 1)
    changed = True
    print("  [patch] hookCtx typed as PluginHookAgentContext")

hookctx_match = re.search(r'const hookCtx(?:: PluginHookAgentContext)? = \{(.*?)\};', content, re.DOTALL)
if hookctx_match:
    hookctx_body = hookctx_match.group(1)
    if "senderId" not in hookctx_body:
        old_hookctx_end = "runId: params.runId,\n      };"
        new_hookctx_end = ("runId: params.runId,\n"
            "        senderId: params.senderId ?? undefined,\n"
            "        senderName: params.senderName ?? undefined,\n"
            "        senderUsername: params.senderUsername ?? undefined,\n"
            "        senderE164: params.senderE164 ?? undefined,\n"
            "      };")
        if old_hookctx_end in content:
            content = content.replace(old_hookctx_end, new_hookctx_end, 1)
            changed = True
            print("  [patch] Added sender fields to run.ts hookCtx")
    else:
        print("  [skip] run.ts hookCtx already has sender fields")

if "hookCtx.model = model;" in content:
    print("  [skip] model/modelRegistry already assigned to hookCtx")
else:
    marker = ("      if (!model) {\n"
        "        throw new FailoverError(error ?? `Unknown model: ${provider}/${modelId}`, {\n"
        "          reason: \"model_not_found\",\n"
        "          provider,\n"
        "          model: modelId,\n"
        "        });\n"
        "      }")
    if marker in content:
        replacement = marker + "\n\n      hookCtx.model = model;\n      hookCtx.modelRegistry = modelRegistry;"
        content = content.replace(marker, replacement)
        changed = True
        print("  [patch] Added hookCtx.model/modelRegistry after resolveModel()")
    else:
        print("  [warn] Could not find resolveModel error check")

bas_block_re = re.compile(
    r'\s+if \(hookRunner\?\.hasHooks\("before_agent_start"\)\) \{\s*'
    r'try \{.*?legacyBeforeAgentStartResult.*?'
    r'\} catch \(hookErr\) \{.*?before_agent_start hook.*?\}'
    r'\s*\}',
    re.DOTALL
)
m = bas_block_re.search(content)
if m:
    content = content[:m.start()] + content[m.end():]
    changed = True
    print("  [patch] Removed before_agent_start from run.ts")
else:
    if 'before_agent_start' not in content or 'hookRunner?.hasHooks("before_agent_start")' not in content:
        print("  [skip] before_agent_start already removed from run.ts")
    else:
        print("  [warn] Could not match before_agent_start block in run.ts")

if "legacyBeforeAgentStartResult: undefined," in content:
    print("  [skip] legacyBeforeAgentStartResult already set to undefined")
elif "legacyBeforeAgentStartResult," in content:
    content = content.replace("legacyBeforeAgentStartResult,", "legacyBeforeAgentStartResult: undefined,", 1)
    changed = True
    print("  [patch] Set legacyBeforeAgentStartResult: undefined")

if changed:
    with open(fpath, "w") as f:
        f.write(content)
PYEOF

  patch_bar "run.ts  sender field forwarding"

  python3 << 'PYEOF'
fpath = "src/agents/pi-embedded-runner/run.ts"
try:
    with open(fpath, "r") as f:
        content = f.read()
except FileNotFoundError:
    print("  [skip] run.ts not found")
    exit(0)

if "senderId: params.senderId," in content:
    idx = content.find("senderId: params.senderId,")
    nearby = content[max(0,idx-200):idx+200]
    if "senderUsername: params.senderUsername," in nearby:
        print("  [skip] run.ts sender fields already present")
    else:
        old = "senderId: params.senderId,"
        new = ("senderId: params.senderId,\n"
               "            senderName: params.senderName,\n"
               "            senderUsername: params.senderUsername,\n"
               "            senderE164: params.senderE164,")
        content = content.replace(old, new, 1)
        with open(fpath, "w") as f:
            f.write(content)
        print("  [patch] run.ts sender fields added")
else:
    old_marker = "spawnedBy: params.spawnedBy,\n            senderIsOwner:"
    if old_marker in content:
        new_block = ("spawnedBy: params.spawnedBy,\n"
                     "            senderId: params.senderId,\n"
                     "            senderName: params.senderName,\n"
                     "            senderUsername: params.senderUsername,\n"
                     "            senderE164: params.senderE164,\n"
                     "            senderIsOwner:")
        content = content.replace(old_marker, new_block, 1)
        with open(fpath, "w") as f:
            f.write(content)
        print("  [patch] run.ts sender fields inserted after spawnedBy")
    else:
        print("  [warn] run.ts: could not find insertion point")
PYEOF

  patch_bar "pi-tools.ts  wrapping order (abort before hooks)"

  python3 << 'PYEOF'
import re
fpath = "src/agents/pi-tools.ts"
try:
    with open(fpath, "r") as f:
        content = f.read()
except FileNotFoundError:
    print("  [skip] pi-tools.ts not found")
    exit(0)

if ("const withAbort = options?.abortSignal" in content
    and "? normalized.map" in content
    and ": normalized;" in content
    and "const withHooks = withAbort.map" in content
    and "return withHooks;" in content):
    print("  [skip] wrapping order already correct")
elif ("const withHooks = normalized.map((tool) =>" in content
      and "return withAbort;" in content):
    hooks_re = re.compile(
        r"(  const withHooks = normalized\.map\(.*?\n(?:.*?\n)*?  \);)\n"
        r"(  const withAbort = options\?\.abortSignal\n"
        r"    \? withHooks\.map\(.*?\n"
        r"    : withHooks;)",
        re.DOTALL
    )
    m = hooks_re.search(content)
    if m:
        hooks_block = m.group(1)
        abort_block = m.group(2)
        new_hooks = hooks_block.replace("normalized.map", "withAbort.map")
        new_abort = abort_block.replace("withHooks.map", "normalized.map").replace(": withHooks;", ": normalized;")
        content = content[:m.start()] + new_abort + "\n" + new_hooks + content[m.end():]
        content = content.replace("return withAbort;", "return withHooks;")
        with open(fpath, "w") as f:
            f.write(content)
        print("  [patch] wrapping order fixed (abort first, hooks last)")
    else:
        print("  [warn] could not match wrapping order blocks via regex")
else:
    print("  [warn] could not determine wrapping order")
PYEOF

  echo ""
  ui_success "Patches applied"
  cd "$prev_dir"
}

build_openclaw() {
  if [[ "$ARMORIQ_SKIP_BUILD" == "true" ]]; then
    ui_info "Skipping build (--skip-build)"
    return 0
  fi

  local prev_dir="$PWD"
  cd "$ARMORIQ_INSTALL_DIR"

  run_quiet_step "Installing dependencies (pnpm install)" pnpm install
  ui_success "Dependencies installed"

  run_quiet_step "Building OpenClaw" pnpm build
  ui_success "Build complete"

  cd "$prev_dir"
}


install_plugin() {
  local plugin_pkg="@armoriq/armorclaw"
  if [[ -n "$ARMORIQ_PLUGIN_VERSION" ]]; then
    plugin_pkg="${plugin_pkg}@${ARMORIQ_PLUGIN_VERSION}"
  fi

  ui_info "Installing ArmorClaw plugin from npm: ${plugin_pkg}"

  rm -rf "$HOME/.openclaw/extensions/armorclaw" 2>/dev/null || true

  node -e "
    const fs = require('fs');
    const f = process.env.HOME + '/.openclaw/openclaw.json';
    try {
      let c = JSON.parse(fs.readFileSync(f, 'utf8'));
      let changed = false;
      if (c.plugins?.entries?.armorclaw) { delete c.plugins.entries.armorclaw; changed = true; }
      if (c.plugins?.installs?.armorclaw) { delete c.plugins.installs.armorclaw; changed = true; }
      if (Array.isArray(c.plugins?.allow)) {
        const idx = c.plugins.allow.indexOf('armorclaw');
        if (idx !== -1) { c.plugins.allow.splice(idx, 1); changed = true; }
      }
      if (changed) fs.writeFileSync(f, JSON.stringify(c, null, 2) + '\n');
    } catch {}
  " 2>/dev/null || true

  local prev_dir="$PWD"
  cd "$ARMORIQ_INSTALL_DIR"

  if [[ -f "openclaw.mjs" ]]; then
    run_quiet_step "Installing ArmorClaw plugin" node openclaw.mjs plugins install "$plugin_pkg"
  elif [[ -f "dist/entry.js" ]]; then
    run_quiet_step "Installing ArmorClaw plugin" node dist/entry.js plugins install "$plugin_pkg"
  else
    ui_error "No openclaw entry point found. Build may have failed."
    cd "$prev_dir"
    exit 1
  fi

  cd "$prev_dir"

  if [[ -d "$HOME/.openclaw/extensions/armorclaw" ]]; then
    ui_success "ArmorClaw plugin installed from npm"
  else
    ui_error "Plugin installation may have failed"
    ui_info "Try manually: cd $ARMORIQ_INSTALL_DIR && openclaw plugins install ${plugin_pkg}"
  fi
}



setup_api_key() {
  if [[ -n "$ARMORIQ_API_KEY" ]]; then
    ui_success "API key provided via --api-key"
    return 0
  fi

  if [[ -n "${ARMORIQ_API_KEY_ENV:-}" ]]; then
    ARMORIQ_API_KEY="$ARMORIQ_API_KEY_ENV"
    ui_success "API key from environment"
    return 0
  fi

  if [[ "$ARMORIQ_SKIP_KEY" == "true" || "$ARMORIQ_NO_PROMPT" == "true" ]]; then
    ui_info "Skipping API key setup"
    return 0
  fi

  if ! is_promptable; then
    ui_info "No TTY, skipping API key. Set ARMORIQ_API_KEY later."
    return 0
  fi

  echo ""
  ui_section "ArmorIQ API Key"
  echo ""
  echo -e "  ${W}Get your API key at:${N}"
  echo ""
  echo -e "    ${CYAN}https://platform.armoriq.ai/${N}"
  echo ""
  echo -e "  ${D}Sign up or log in, then go to Settings > API Keys.${N}"
  echo ""

  local choice
  choice="$(prompt_choice "Do you have an API key?" \
    "Yes, enter it now" \
    "No, I'll set it up later")"

  case "$choice" in
    "Yes, enter it now")
      ARMORIQ_API_KEY="$(prompt_input "Paste your ArmorIQ API key (ak_live_...)")"
      if [[ -z "$ARMORIQ_API_KEY" ]]; then
        ui_warn "No key entered, skipping"
      else
        ui_success "API key saved"
      fi
      ;;
    *)
      ui_info "Skipped. Set ARMORIQ_API_KEY in your env or openclaw.json later."
      ;;
  esac
}


setup_telegram() {
  if [[ -n "$ARMORIQ_TELEGRAM_TOKEN" ]]; then
    ui_success "Telegram bot token provided"
    return 0
  fi

  if [[ "$ARMORIQ_NO_PROMPT" == "true" ]]; then
    ui_info "Skipping Telegram setup (non-interactive)"
    return 0
  fi

  if ! is_promptable; then
    ui_info "No TTY, skipping Telegram. Set ARMORIQ_TELEGRAM_TOKEN later."
    return 0
  fi

  echo ""
  ui_section "Telegram Bot Setup"
  echo ""
  echo -e "  ${W}Create a bot with @BotFather on Telegram:${N}"
  echo -e "    ${CYAN}https://t.me/BotFather${N}"
  echo ""
  echo -e "  ${D}1. Open Telegram and chat with @BotFather${N}"
  echo -e "  ${D}2. Run /newbot and follow the prompts${N}"
  echo -e "  ${D}3. Copy the bot token${N}"
  echo ""

  local choice
  choice="$(prompt_choice "Set up Telegram bot?" \
    "Yes, I have a bot token" \
    "No, skip for now")"

  case "$choice" in
    "Yes, I have a bot token")
      ARMORIQ_TELEGRAM_TOKEN="$(prompt_input "Paste your Telegram bot token")"
      if [[ -z "$ARMORIQ_TELEGRAM_TOKEN" ]]; then
        ui_warn "No token entered, skipping Telegram"
        return 0
      fi

      local dm_choice
      dm_choice="$(prompt_choice "DM policy (who can message the bot?)" \
        "open - allow all DMs" \
        "pairing - require pairing code approval" \
        "allowlist - only allowed user IDs")"
      case "$dm_choice" in
        "open"*)     ARMORIQ_TELEGRAM_DM_POLICY="open" ;;
        "pairing"*) ARMORIQ_TELEGRAM_DM_POLICY="pairing" ;;
        "allowlist"*) ARMORIQ_TELEGRAM_DM_POLICY="allowlist" ;;
      esac

      local stream_choice
      stream_choice="$(prompt_choice "Stream mode (reply streaming in DMs)" \
        "partial - stream partial updates (recommended)" \
        "block - chunked block updates" \
        "off - no streaming")"
      case "$stream_choice" in
        "partial"*) ARMORIQ_TELEGRAM_STREAM_MODE="partial" ;;
        "block"*)   ARMORIQ_TELEGRAM_STREAM_MODE="block" ;;
        "off"*)     ARMORIQ_TELEGRAM_STREAM_MODE="off" ;;
      esac

      ui_success "Telegram configured (${ARMORIQ_TELEGRAM_DM_POLICY}, stream: ${ARMORIQ_TELEGRAM_STREAM_MODE})"
      ;;
    *)
      ui_info "Skipped. Set ARMORIQ_TELEGRAM_TOKEN later."
      ;;
  esac
}


setup_agent_model() {
  if [[ -n "$ARMORIQ_MODEL" ]]; then
    ui_success "Model already set: ${ARMORIQ_MODEL}"
    return 0
  fi

  if [[ "$ARMORIQ_NO_PROMPT" == "true" ]]; then
    return 0
  fi

  if ! is_promptable; then
    return 0
  fi

  echo ""
  ui_section "Agent Model"
  echo ""

  local model_choice
  model_choice="$(prompt_choice "Select primary LLM provider" \
    "OpenAI GPT (gpt-5.2)" \
    "Google Gemini (gemini-2.5-flash)" \
    "OpenRouter (any model)" \
    "Custom model ID")"

  case "$model_choice" in
    "OpenAI GPT"*)
      ARMORIQ_MODEL="openai/gpt-5.2"
      if [[ -z "$ARMORIQ_OPENAI_KEY" ]]; then
        ARMORIQ_OPENAI_KEY="$(prompt_input "Paste your OpenAI API key (sk-...)")"
      fi
      ;;
    "Google Gemini"*)
      ARMORIQ_MODEL="google/gemini-2.5-flash"
      if [[ -z "$ARMORIQ_GEMINI_KEY" ]]; then
        ARMORIQ_GEMINI_KEY="$(prompt_input "Paste your Google Gemini API key")"
      fi
      ;;
    "OpenRouter"*)
      ARMORIQ_MODEL="openrouter/auto"
      if [[ -z "$ARMORIQ_OPENROUTER_KEY" ]]; then
        ARMORIQ_OPENROUTER_KEY="$(prompt_input "Paste your OpenRouter API key (sk-or-...)")"
      fi
      ;;
    "Custom"*)
      ARMORIQ_MODEL="$(prompt_input "Enter model ID (e.g. openai/gpt-5.2, anthropic/claude-4)")"
      ;;
  esac

  if [[ -n "$ARMORIQ_MODEL" ]]; then
    ui_success "Model: ${ARMORIQ_MODEL}"
  fi
}


configure_openclaw_json() {
  local config_dir="$HOME/.openclaw"
  local config_file="${config_dir}/openclaw.json"

  mkdir -p "$config_dir"

  local api_key_val=""
  [[ -n "$ARMORIQ_API_KEY" ]] && api_key_val="$ARMORIQ_API_KEY"

  local model_val="${ARMORIQ_MODEL}"
  local openai_key_val="${ARMORIQ_OPENAI_KEY}"
  local openrouter_key_val="${ARMORIQ_OPENROUTER_KEY}"
  local anthropic_key_val="${ARMORIQ_ANTHROPIC_KEY}"
  local gemini_key_val="${ARMORIQ_GEMINI_KEY}"
  local telegram_token="${ARMORIQ_TELEGRAM_TOKEN}"
  local telegram_dm_policy="${ARMORIQ_TELEGRAM_DM_POLICY}"
  local telegram_stream_mode="${ARMORIQ_TELEGRAM_STREAM_MODE}"

  node -e "
    const fs = require('fs');
    const path = require('path');
    let c = {};
    try { c = JSON.parse(fs.readFileSync('${config_file}', 'utf8')); } catch {}

    if (!c.agents) c.agents = {};
    if (!c.agents.defaults) c.agents.defaults = {};
    if (!c.commands) c.commands = {};
    c.commands.native = c.commands.native || 'auto';
    c.commands.nativeSkills = c.commands.nativeSkills || 'auto';
    if (!c.gateway) c.gateway = {};
    c.gateway.mode = c.gateway.mode || 'local';
    if (!c.plugins) c.plugins = {};
    c.plugins.enabled = true;
    if (!c.plugins.entries) c.plugins.entries = {};
    if (!c.channels) c.channels = {};
    if (!c.messages) c.messages = {};
    c.messages.ackReactionScope = c.messages.ackReactionScope || 'group-mentions';

    // model config
    const modelVal = '${model_val}';
    if (modelVal) {
      if (!c.agents.defaults.model) c.agents.defaults.model = {};
      c.agents.defaults.model.primary = modelVal;
    } else if (!c.agents.defaults.model?.primary) {
      if (!c.agents.defaults.model) c.agents.defaults.model = {};
      c.agents.defaults.model.primary = 'openai/gpt-5.2';
    }

    // auth profiles in openclaw.json (no apiKey here, keys go in agent auth-profiles.json)
    if (!c.auth) c.auth = {};
    if (!c.auth.profiles) c.auth.profiles = {};
    if (!c.auth.order) c.auth.order = {};

    const openaiKey = '${openai_key_val}';
    const openrouterKey = '${openrouter_key_val}';
    const anthropicKey = '${anthropic_key_val}';
    const geminiKey = '${gemini_key_val}';
    const telegramToken = '${telegram_token}';
    const telegramDmPolicy = '${telegram_dm_policy}';
    const telegramStreamMode = '${telegram_stream_mode}';

    if (openaiKey) {
      c.auth.profiles['openai:default'] = { provider: 'openai', mode: 'api_key' };
      c.auth.order.openai = c.auth.order.openai || ['openai:default'];
    }
    if (openrouterKey) {
      c.auth.profiles['openrouter:default'] = { provider: 'openrouter', mode: 'api_key' };
      c.auth.order.openrouter = c.auth.order.openrouter || ['openrouter:default'];
    }
    if (anthropicKey) {
      c.auth.profiles['anthropic:default'] = { provider: 'anthropic', mode: 'api_key' };
      c.auth.order.anthropic = c.auth.order.anthropic || ['anthropic:default'];
    }
    if (geminiKey) {
      c.auth.profiles['google:default'] = { provider: 'google', mode: 'api_key' };
      c.auth.order.google = c.auth.order.google || ['google:default'];
    }

    // Telegram channel
    if (telegramToken) {
      c.channels.telegram = {
        enabled: true,
        botToken: telegramToken,
        dmPolicy: telegramDmPolicy || 'open',
        allowFrom: ['*'],
        groupPolicy: 'allowlist',
        streamMode: telegramStreamMode || 'partial',
        ...(c.channels.telegram || {}),
      };
      c.channels.telegram.botToken = telegramToken;
      if (!c.plugins.entries.telegram) c.plugins.entries.telegram = {};
      c.plugins.entries.telegram.enabled = true;
      if (!c.plugins.allow) c.plugins.allow = [];
      if (!c.plugins.allow.includes('telegram')) c.plugins.allow.push('telegram');
    }

    // armorclaw always in allow list
    if (!c.plugins.allow) c.plugins.allow = [];
    if (!c.plugins.allow.includes('armorclaw')) c.plugins.allow.unshift('armorclaw');

    // armorclaw plugin
    const existing = c.plugins.entries.armorclaw?.config || {};
    const newConfig = {
      enabled: true,
      ...existing,
      policyUpdateEnabled: existing.policyUpdateEnabled ?? true,
      policyUpdateAllowList: existing.policyUpdateAllowList?.length ? existing.policyUpdateAllowList : ['*'],
      userId: existing.userId || 'default-user',
      agentId: existing.agentId || 'openclaw-agent-001',
      contextId: existing.contextId || 'default',
      policyStorePath: existing.policyStorePath || '${config_dir}/armoriq.policy.json',
      iapEndpoint: existing.iapEndpoint || 'https://customer-iap.armoriq.ai',
      proxyEndpoint: existing.proxyEndpoint || 'https://customer-proxy.armoriq.ai',
      backendEndpoint: existing.backendEndpoint || 'https://customer-api.armoriq.ai',
    };
    const apiKey = '${api_key_val}';
    if (apiKey) newConfig.apiKey = apiKey;
    c.plugins.entries.armorclaw = {
      ...c.plugins.entries.armorclaw,
      enabled: true,
      config: newConfig
    };
    fs.writeFileSync('${config_file}', JSON.stringify(c, null, 2) + '\\n');

    // write actual API keys into agent auth-profiles.json (where OpenClaw reads them)
    // format: { version: 1, profiles: { "provider:default": { type: "api_key", provider, key } }, order: {} }
    const agentAuthProfiles = {};
    const agentAuthOrder = {};
    if (openaiKey) {
      agentAuthProfiles['openai:default'] = { type: 'api_key', provider: 'openai', key: openaiKey };
      agentAuthOrder.openai = ['openai:default'];
    }
    if (openrouterKey) {
      agentAuthProfiles['openrouter:default'] = { type: 'api_key', provider: 'openrouter', key: openrouterKey };
      agentAuthOrder.openrouter = ['openrouter:default'];
    }
    if (anthropicKey) {
      agentAuthProfiles['anthropic:default'] = { type: 'api_key', provider: 'anthropic', key: anthropicKey };
      agentAuthOrder.anthropic = ['anthropic:default'];
    }
    if (geminiKey) {
      agentAuthProfiles['google:default'] = { type: 'api_key', provider: 'google', key: geminiKey };
      agentAuthOrder.google = ['google:default'];
    }

    if (Object.keys(agentAuthProfiles).length > 0) {
      const authPaths = [
        path.join('${config_dir}', 'auth-profiles.json'),
        path.join('${config_dir}', 'agents', 'main', 'agent', 'auth-profiles.json'),
      ];
      for (const apFile of authPaths) {
        try {
          fs.mkdirSync(path.dirname(apFile), { recursive: true });
          let store = { version: 1, profiles: {}, order: {} };
          try {
            const raw = JSON.parse(fs.readFileSync(apFile, 'utf8'));
            if (raw.profiles) store = raw;
          } catch {}
          store.profiles = { ...store.profiles, ...agentAuthProfiles };
          store.order = { ...store.order, ...agentAuthOrder };
          fs.writeFileSync(apFile, JSON.stringify(store, null, 2) + '\\n');
        } catch {}
      }
    }
  " 2>/dev/null

  ui_success "openclaw.json configured"
}

write_env_file() {
  local env_file="${ARMORIQ_INSTALL_DIR}/.env"

  if [[ -f "$env_file" ]]; then
    if grep -q "ARMORIQ_API_KEY" "$env_file" 2>/dev/null; then
      ui_info ".env already has ArmorIQ vars"
      if [[ -n "$ARMORIQ_API_KEY" ]]; then
        sed -i.bak "s|^ARMORIQ_API_KEY=.*|ARMORIQ_API_KEY=${ARMORIQ_API_KEY}|" "$env_file"
        rm -f "${env_file}.bak"
        ui_success "Updated ARMORIQ_API_KEY in .env"
      fi
      return 0
    fi
  fi

  local key_val=""
  [[ -n "$ARMORIQ_API_KEY" ]] && key_val="$ARMORIQ_API_KEY" || key_val="ak_live_YOUR_KEY_HERE"

  cat >> "$env_file" << ENVEOF

ARMORIQ_API_KEY=${key_val}
IAP_BACKEND_URL=https://customer-api.armoriq.ai
CSRG_URL=https://customer-iap.armoriq.ai
IAP_ENDPOINT=https://customer-iap.armoriq.ai
PROXY_ENDPOINT=https://customer-proxy.armoriq.ai
BACKEND_ENDPOINT=https://customer-api.armoriq.ai
ENVEOF

  ui_success ".env written with ArmorIQ endpoints"
}


show_plan() {
  ui_section "Install plan"
  ui_kv "OS" "$OS"
  ui_kv "OpenClaw version" "v${ARMORIQ_OC_VERSION}"
  ui_kv "Install directory" "$ARMORIQ_INSTALL_DIR"

  local plugin_pkg="@armoriq/armorclaw"
  if [[ -n "$ARMORIQ_PLUGIN_VERSION" ]]; then
    plugin_pkg="${plugin_pkg}@${ARMORIQ_PLUGIN_VERSION}"
  else
    plugin_pkg="${plugin_pkg}@latest"
  fi
  ui_kv "Plugin package" "$plugin_pkg"

  ui_kv "Model" "${ARMORIQ_MODEL:-openai/gpt-5.2 (default)}"
  [[ -n "$ARMORIQ_OPENAI_KEY" ]] && ui_kv "OpenAI key" "provided"
  [[ -n "$ARMORIQ_OPENROUTER_KEY" ]] && ui_kv "OpenRouter key" "provided"
  [[ -n "$ARMORIQ_ANTHROPIC_KEY" ]] && ui_kv "Anthropic key" "provided"
  [[ -n "$ARMORIQ_GEMINI_KEY" ]] && ui_kv "Gemini key" "provided"
  if [[ -n "$ARMORIQ_TELEGRAM_TOKEN" ]]; then
    ui_kv "Telegram" "enabled (dm: ${ARMORIQ_TELEGRAM_DM_POLICY}, stream: ${ARMORIQ_TELEGRAM_STREAM_MODE})"
  else
    ui_kv "Telegram" "will prompt"
  fi

  if [[ -n "$ARMORIQ_API_KEY" ]]; then
    ui_kv "API key" "provided"
  elif [[ "$ARMORIQ_SKIP_KEY" == "true" ]]; then
    ui_kv "API key" "skipped"
  else
    ui_kv "API key" "will prompt"
  fi

  if [[ "$ARMORIQ_DRY_RUN" == "true" ]]; then
    ui_kv "Dry run" "yes"
  fi
}

main() {
  bootstrap_gum || true
  print_banner
  detect_os

  if [[ -z "$ARMORIQ_INSTALL_DIR" ]]; then
    ARMORIQ_INSTALL_DIR="$HOME/openclaw-armoriq"
  fi

  ensure_node
  resolve_version
  show_plan

  if [[ "$ARMORIQ_DRY_RUN" == "true" ]]; then
    ui_success "Dry run complete"
    return 0
  fi

  ui_stage "Preparing environment"
  ensure_git
  ensure_pnpm
  ensure_python3

  ui_stage "Cloning OpenClaw v${ARMORIQ_OC_VERSION}"
  clone_openclaw

  ui_stage "Applying ArmorClaw patches"
  apply_patches

  ui_stage "Building OpenClaw"
  build_openclaw

  ui_stage "Setting up ArmorClaw"
  install_plugin

  ui_stage "Configuring channels and agent"
  setup_telegram
  setup_agent_model
  setup_api_key

  ui_stage "Writing configuration"
  configure_openclaw_json
  write_env_file

  echo ""
  ui_celebrate "ArmorClaw installed successfully on OpenClaw v${ARMORIQ_OC_VERSION}"
  local completion_msg
  completion_msg="$(pick_completion_message)"
  echo -e "${MUTED}${completion_msg}${N}"
  echo ""

  ui_section "Quick reference"
  ui_kv "OpenClaw" "$ARMORIQ_INSTALL_DIR"
  ui_kv "Plugin" "$HOME/.openclaw/extensions/armorclaw"
  ui_kv "Config" "$HOME/.openclaw/openclaw.json"
  ui_kv "Env file" "${ARMORIQ_INSTALL_DIR}/.env"
  if [[ -n "$ARMORIQ_TELEGRAM_TOKEN" ]]; then
    ui_kv "Telegram" "enabled (dm: ${ARMORIQ_TELEGRAM_DM_POLICY})"
  fi
  ui_kv "Model" "${ARMORIQ_MODEL:-openai/gpt-5.2}"
  if [[ -n "$ARMORIQ_API_KEY" ]]; then
    ui_kv "API key" "configured"
  else
    ui_kv "API key" "not set (add to .env or openclaw.json)"
    echo ""
    echo -e "  ${W}Get your key at: ${CYAN}https://platform.armoriq.ai/${N}"
  fi
  echo ""

  ui_kv "Docs" "https://docs.armoriq.ai"
  ui_kv "Platform" "https://platform.armoriq.ai"

  print_footer
}

parse_args "$@"
main