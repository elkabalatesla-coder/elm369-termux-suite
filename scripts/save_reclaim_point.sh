#!/data/data/com.termux/files/usr/bin/bash
set -e

CHECKPOINT_ROOT="${HOME}/termux_checkpoints"
mkdir -p "${CHECKPOINT_ROOT}"

create_save_point() {
  local tag="${1:-checkpoint}"
  local stamp
  stamp="$(date +%Y%m%d_%H%M%S)"
  local label="${tag}_${stamp}"
  local archive="${CHECKPOINT_ROOT}/${label}.tar.gz"
  local latest_link="${CHECKPOINT_ROOT}/latest.tar.gz"

  local targets=()
  for item in \
    "${HOME}/.bashrc" \
    "${HOME}/.ctxsw_prompt.sh" \
    "${HOME}/.ctxsw.sh" \
    "${HOME}/setup_gyro_liquid.sh" \
    "${HOME}/fix_termux.sh" \
    "${HOME}/setup_qbit_engines.sh" \
    "${HOME}/setup_qbit_audio.sh" \
    "${HOME}/setup_ai_audio.sh" \
    "${HOME}/list_termux_env.sh" \
    "${HOME}/gyro_liquid_3d" \
    "${HOME}/qbit_engines_lab" \
    "${HOME}/qbit_audio_lab"
  do
    if [ -e "${item}" ]; then
      targets+=("${item}")
    fi
  done

  if [ "${#targets[@]}" -eq 0 ]; then
    echo "No target files or directories found to save."
    exit 1
  fi

  tar -czf "${archive}" "${targets[@]}" 2>/dev/null || tar -czf "${archive}" -C "${HOME}" .
  ln -sf "${archive}" "${latest_link}"
  echo "SAVED CHECKPOINT: ${archive}"
  echo "LATEST POINTER:   ${latest_link}"
}

reclaim_point() {
  local source_archive="${1:-${CHECKPOINT_ROOT}/latest.tar.gz}"
  if [ ! -e "${source_archive}" ]; then
    echo "Checkpoint not found: ${source_archive}"
    exit 1
  fi

  local resolved_archive
  resolved_archive="$(readlink -f "${source_archive}")"
  local safety_backup="${CHECKPOINT_ROOT}/pre_reclaim_$(date +%Y%m%d_%H%M%S).tar.gz"
  tar -czf "${safety_backup}" -C "${HOME}" \
    .bashrc \
    gyro_liquid_3d \
    qbit_engines_lab \
    qbit_audio_lab \
    2>/dev/null || true

  tar -xzf "${resolved_archive}" -C /
  echo "RECLAIMED FROM:   ${resolved_archive}"
  echo "SAFETY BACKUP:    ${safety_backup}"
  echo "Reload shell if needed: source ~/.bashrc"
}

list_points() {
  echo "=== SAVED CHECKPOINTS IN ${CHECKPOINT_ROOT} ==="
  ls -lh "${CHECKPOINT_ROOT}"/*.tar.gz 2>/dev/null || echo "No checkpoints found."
}

case "${1:-save}" in
  save)
    create_save_point "${2:-checkpoint}"
    ;;
  reclaim)
    reclaim_point "${2:-${CHECKPOINT_ROOT}/latest.tar.gz}"
    ;;
  list)
    list_points
    ;;
  *)
    echo "Usage: $0 {save [label] | reclaim [archive.tar.gz] | list}"
    exit 1
    ;;
esac
