#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [ -x dv/tests/run.sh ]; then
  echo "Running project regression hook: dv/tests/run.sh"
  exec dv/tests/run.sh
fi

echo "No regression hook found. Falling back to make sim."
exec make sim
