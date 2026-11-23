#!/data/data/com.termux/files/usr/bin/bash
set -u

CHECKPOINT_DIR="${HOME}/elm369_checkpoints"
TARGETS=(
  "gyro_liquid_3d"
  "qbit_engines_lab"
  "qbit_audio_lab"
  "elm369_training_lab"
  "elm369-termux-suite"
)

mkdir -p "${CHECKPOINT_DIR}"

require_hash_tool() {
  if ! command -v sha256sum >/dev/null 2>&1; then
    echo "Missing sha256sum. Install coreutils in Termux with: pkg install -y coreutils"
    return 1
  fi
}

list_checkpoints() {
  echo ""
  echo "Available checkpoints in ${CHECKPOINT_DIR}:"
  local found=0
  for archive in "${CHECKPOINT_DIR}"/*.tar.gz; do
    [ -e "$archive" ] || continue
    found=1
    local base manifest status
    base="$(basename "$archive")"
    manifest="${archive}.sha256"
    if [ -f "$manifest" ]; then
      if sha256sum -c "$manifest" --status >/dev/null 2>&1; then
        status="SHA256_OK"
      else
        status="SHA256_MISMATCH"
      fi
    else
      status="NO_MANIFEST"
    fi
    printf "  - %s [%s]\n" "$base" "$status"
  done
  if [ "$found" -eq 0 ]; then
    echo "  (none)"
  fi
}

create_checkpoint() {
  require_hash_tool || return 1
  local stamp note safe_note slug archive manifest
  stamp="$(date +%Y%m%d_%H%M%S)"
  read -r -p "Checkpoint label/note [checkpoint]: " note
  note="${note:-checkpoint}"
  safe_note="$(printf '%s' "$note" | tr -cs 'A-Za-z0-9_-' '_' | sed 's/^_//;s/_$//')"
  slug="${safe_note:-checkpoint}"

  archive="${CHECKPOINT_DIR}/elm369_${stamp}_${slug}.tar.gz"
  manifest="${archive}.sha256"

  local present_targets=()
  for item in "${TARGETS[@]}"; do
    if [ -e "${HOME}/${item}" ]; then
      present_targets+=("$item")
    fi
  done

  if [ "${#present_targets[@]}" -eq 0 ]; then
    echo "No target directories found under ${HOME} to archive."
    return 1
  fi

  echo "Creating archive: $archive"
  tar -czf "$archive" -C "${HOME}" "${present_targets[@]}" || return 1

  (
    cd "${CHECKPOINT_DIR}" && sha256sum "$(basename "$archive")" > "$(basename "$manifest")"
  ) || return 1

  echo "Wrote SHA-256 manifest: $manifest"
  echo "Verifying SHA-256 manifest..."
  (
    cd "${CHECKPOINT_DIR}" && sha256sum -c "$(basename "$manifest")"
  ) || {
    echo "ERROR: Newly created checkpoint failed SHA-256 verification!"
    return 1
  }
  echo "Checkpoint saved and SHA-256 verified."
}

verify_checkpoint_file() {
  require_hash_tool || return 1
  local archive="$1"
  local manifest="${archive}.sha256"

  if [ ! -f "$archive" ]; then
    echo "Archive not found: $archive"
    return 1
  fi
  if [ ! -f "$manifest" ]; then
    echo "Manifest not found for archive: $manifest"
    return 1
  fi

  echo "Verifying $(basename "$archive") against $(basename "$manifest")..."
  (
    cd "${CHECKPOINT_DIR}" && sha256sum -c "$(basename "$manifest")"
  )
}

reclaim_checkpoint() {
  require_hash_tool || return 1
  list_checkpoints
  echo ""
  read -r -p "Enter checkpoint filename to reclaim (e.g. elm369_20261123_110000_checkpoint.tar.gz): " fname
  [ -n "$fname" ] || {
    echo "No filename entered."
    return 1
  }

  local archive="${CHECKPOINT_DIR}/${fname}"
  if ! verify_checkpoint_file "$archive"; then
    echo "ABORTED: SHA-256 verification failed or manifest missing. Reclaim cancelled."
    return 1
  fi

  read -r -p "Overwrite matching workspaces under ${HOME} from $(basename "$archive")? [y/N]: " confirm
  case "$confirm" in
    y|Y|yes|YES)
      tar -xzf "$archive" -C "${HOME}" || return 1
      echo "Reclaimed workspace from verified checkpoint: $(basename "$archive")"
      ;;
    *)
      echo "Reclaim cancelled."
      ;;
  esac
}

verify_menu() {
  list_checkpoints
  echo ""
  read -r -p "Enter checkpoint filename to verify (or 'all' for all manifests): " target
  [ -n "$target" ] || return 1

  if [ "$target" = "all" ]; then
    local any=0 rc=0
    for m in "${CHECKPOINT_DIR}"/*.tar.gz.sha256; do
      [ -e "$m" ] || continue
      any=1
      (
        cd "${CHECKPOINT_DIR}" && sha256sum -c "$(basename "$m")"
      ) || rc=1
    done
    [ "$any" -eq 1 ] || echo "No .sha256 manifests found in ${CHECKPOINT_DIR}."
    return "$rc"
  fi

  verify_checkpoint_file "${CHECKPOINT_DIR}/${target}"
}

while true; do
  echo ""
  echo "=========================================="
  echo "   ELM369 SAVE / RECLAIM (SHA-256)        "
  echo "=========================================="
  echo "  1) Save New Checkpoint + Generate SHA-256"
  echo "  2) Reclaim Checkpoint (Verify SHA-256 First)"
  echo "  3) Verify Checkpoint SHA-256 Manifest(s)"
  echo "  4) List Checkpoints & Hash Status"
  echo "  0) Exit"
  echo "=========================================="
  read -r -p "Select an option [0-4]: " opt

  case "$opt" in
    1) create_checkpoint ;;
    2) reclaim_checkpoint ;;
    3) verify_menu ;;
    4) list_checkpoints ;;
    0) break ;;
    *) echo "Invalid option: $opt" ;;
  esac
done
