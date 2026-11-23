#!/data/data/com.termux/files/usr/bin/bash
set -u

REPO_DIR="${HOME}/elm369-termux-suite"
TRAINING_STATE_FILE="${HOME}/elm369_training_lab/training_state.json"

prompt_module_args() {
  local hint="$1"
  local raw_args=""
  echo "Optional CLI args hint: ${hint}"
  read -r -p "Extra args (press Enter for none): " raw_args
  EXTRA_MODULE_ARGS=()
  if [ -n "$raw_args" ]; then
    # Split unquoted tokens safely into an array for Python argparse
    read -r -a EXTRA_MODULE_ARGS <<< "$raw_args"
  fi
}

run_python_module() {
  local script_path="$1"
  local label="$2"
  local hint="$3"
  if [ ! -f "$script_path" ]; then
    echo "Missing module: $script_path"
    return 1
  fi
  echo ""
  echo ">>> Preparing $label ($script_path)"
  prompt_module_args "$hint"
  echo ">>> Launching $label..."
  if [ "${#EXTRA_MODULE_ARGS[@]}" -gt 0 ]; then
    python "$script_path" "${EXTRA_MODULE_ARGS[@]}"
  else
    python "$script_path"
  fi
}

run_shell_script() {
  local script_path="$1"
  local label="$2"
  if [ ! -f "$script_path" ]; then
    echo "Missing script: $script_path"
    return 1
  fi
  echo ""
  echo ">>> Running $label ($script_path)"
  bash "$script_path"
}

show_status_dashboard() {
  echo ""
  echo "=========================================="
  echo "       ELM369 STATUS DASHBOARD            "
  echo "=========================================="

  if [ -d "${REPO_DIR}/.git" ]; then
    local branch pending_count
    branch="$(git -C "${REPO_DIR}" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")"
    pending_count="$(git -C "${REPO_DIR}" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
    echo "Git Repo      : ${REPO_DIR}"
    echo "Git Branch    : ${branch}"
    if [ "$pending_count" -eq 0 ]; then
      echo "Pending Edits : none (clean working tree)"
    else
      echo "Pending Edits : ${pending_count} uncommitted item(s)"
      git -C "${REPO_DIR}" status --short
    fi
  else
    echo "Git Repo      : not initialized at ${REPO_DIR}"
    echo "Git Branch    : n/a"
    echo "Pending Edits : n/a"
  fi

  echo "------------------------------------------"

  if [ -f "${TRAINING_STATE_FILE}" ]; then
    python - "${TRAINING_STATE_FILE}" << 'PYEOF'
import json
import sys

path = sys.argv[1]
try:
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    episode = data.get("episode", 0)
    audit_pass = data.get("audit_pass", False)
    domains = data.get("domains", {})
    if isinstance(domains, dict) and domains:
        avg_readiness = sum(
            float(d.get("readiness", 0.0)) for d in domains.values() if isinstance(d, dict)
        ) / len(domains)
    else:
        avg_readiness = 0.0
    print(f"Training File : {path}")
    print(f"Episode       : {episode}")
    print(f"audit_pass    : {audit_pass}")
    print(f"Avg Readiness : {avg_readiness:.4f}")
except Exception as exc:
    print(f"Training File : {path}")
    print(f"audit_pass    : unreadable ({exc})")
PYEOF
  else
    echo "Training File : missing (${TRAINING_STATE_FILE})"
    echo "audit_pass    : False (no training state yet)"
  fi

  echo "=========================================="
}

push_to_github() {
  echo ""
  echo ">>> Syncing and pushing ELM369 suite to GitHub"
  if [ -f "${HOME}/prepare_elm369_github_repo.sh" ]; then
    bash "${HOME}/prepare_elm369_github_repo.sh" || return 1
  fi
  if [ ! -d "${REPO_DIR}/.git" ]; then
    echo "Repository not initialized at ${REPO_DIR}"
    return 1
  fi
  cd "${REPO_DIR}" || return 1
  git add -A
  if ! git diff --cached --quiet; then
    read -r -p "Commit message [Update ELM369 Termux suite]: " commit_msg
    commit_msg="${commit_msg:-Update ELM369 Termux suite}"
    git commit -m "$commit_msg"
  fi
  git push -u origin main
}

while true; do
  echo ""
  echo "=========================================="
  echo "        PROJECT ELM369 MASTER LAUNCHER    "
  echo "=========================================="
  echo "  1) 3D Liquid & Color Wheel (gyro_liquid.py)"
  echo "  2) Qbit & Engine Matrix (qbit_engines_termux.py)"
  echo "  3) Qbit Audio Controller (qbit_audio_termux.py)"
  echo "  4) AI Audio Assistant (ai_audio_assistant.py)"
  echo "  5) ELM369 Training Program (elm369_training_program.py)"
  echo "  6) Save / Reclaim Checkpoint (save_reclaim_point.sh)"
  echo "  7) Sync, Commit & Push to GitHub (elm369-termux-suite)"
  echo "  8) Refresh GitHub Repo Bundle (prepare_elm369_github_repo.sh)"
  echo "  9) Status Dashboard (Git Branch, Changes & audit_pass)"
  echo "  0) Exit"
  echo "=========================================="
  read -r -p "Select an option [0-9]: " choice

  case "$choice" in
    1)
      run_python_module \
        "${HOME}/gyro_liquid_3d/gyro_liquid.py" \
        "3D Liquid & Color Wheel" \
        "--lock-hue 180 or --unlock"
      ;;
    2)
      run_python_module \
        "${HOME}/qbit_engines_lab/qbit_engines_termux.py" \
        "Multi-Layer Qbit & Engine Matrix" \
        "--lock-hue 240 or --unlock"
      ;;
    3)
      run_python_module \
        "${HOME}/qbit_audio_lab/qbit_audio_termux.py" \
        "Qbit Audio Controller" \
        "--lock-hue 120 or --unlock"
      ;;
    4)
      run_python_module \
        "${HOME}/qbit_audio_lab/ai_audio_assistant.py" \
        "AI Audio Assistant" \
        "--lock-hue 300 or --unlock"
      ;;
    5)
      run_python_module \
        "${HOME}/elm369_training_lab/elm369_training_program.py" \
        "Project ELM369 Training Program" \
        "--episodes 5 --domain drones --lock-hue 210"
      ;;
    6)
      run_shell_script "${HOME}/save_reclaim_point.sh" "Save / Reclaim Checkpoint"
      ;;
    7)
      push_to_github
      ;;
    8)
      run_shell_script "${HOME}/prepare_elm369_github_repo.sh" "Refresh GitHub Repo Bundle"
      ;;
    9)
      show_status_dashboard
      ;;
    0)
      echo "Exiting ELM369 Master Launcher."
      break
      ;;
    *)
      echo "Invalid selection: $choice"
      ;;
  esac
done
