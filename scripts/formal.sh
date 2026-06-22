#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [ -x formal/run.sh ]; then
  echo "Running project formal hook: formal/run.sh"
  exec formal/run.sh
fi

SBY_FILES=()
while IFS= read -r file; do
  SBY_FILES+=("$file")
done < <(find formal -type f -name '*.sby' 2>/dev/null | sort)

if [ "${#SBY_FILES[@]}" -eq 0 ]; then
  echo "BLOCKED: no formal/run.sh or .sby files found under formal"
  exit 2
fi

if command -v sby >/dev/null 2>&1; then
  for job in "${SBY_FILES[@]}"; do
    echo "Running sby $job"
    sby -f "$job"
  done
else
  echo "BLOCKED: sby not found. Install SymbiYosys from the YosysHQ sby repository."
  exit 127
fi
