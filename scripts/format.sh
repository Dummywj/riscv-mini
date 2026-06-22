#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

mapfile -t RTL_FILES < <(find rtl/src rtl/include dv/tb dv/assertions -type f \( -name '*.v' -o -name '*.sv' -o -name '*.vh' -o -name '*.svh' \) 2>/dev/null | sort)

if [ "${#RTL_FILES[@]}" -eq 0 ]; then
  echo "No Verilog/SystemVerilog files found to format."
  exit 0
fi

if command -v verible-verilog-format >/dev/null 2>&1; then
  echo "Running verible-verilog-format"
  verible-verilog-format --inplace "${RTL_FILES[@]}"
else
  echo "BLOCKED: verible-verilog-format not found. Install with Homebrew."
  exit 127
fi
