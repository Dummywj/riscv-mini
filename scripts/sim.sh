#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

mkdir -p sim/build

if [ -x sim/run.sh ]; then
  echo "Running project simulation hook: sim/run.sh"
  exec sim/run.sh
fi

if [ -f dv/Makefile ]; then
  echo "Running project DV Makefile"
  exec make -C dv sim
fi

RTL_FILES=()
while IFS= read -r file; do
  RTL_FILES+=("$file")
done < <(find rtl/src -type f \( -name '*.v' -o -name '*.sv' \) 2>/dev/null | sort)

TB_FILES=()
while IFS= read -r file; do
  TB_FILES+=("$file")
done < <(find dv/tb -type f \( -name '*.v' -o -name '*.sv' \) 2>/dev/null | sort)

if [ "${#RTL_FILES[@]}" -eq 0 ]; then
  echo "BLOCKED: no RTL source files found under rtl/src"
  exit 2
fi

if [ "${#TB_FILES[@]}" -eq 0 ]; then
  echo "BLOCKED: no testbench files found under dv/tb"
  exit 2
fi

if command -v iverilog >/dev/null 2>&1 && command -v vvp >/dev/null 2>&1; then
  echo "Running iverilog simulation fallback"
  iverilog -g2012 -I rtl/include -o sim/build/simv "${RTL_FILES[@]}" "${TB_FILES[@]}"
  vvp sim/build/simv
elif command -v verilator >/dev/null 2>&1; then
  echo "BLOCKED: verilator is installed, but no project-specific sim/run.sh exists. Add sim/run.sh for Verilator build options."
  exit 2
else
  echo "BLOCKED: no supported simulator found. Install icarus-verilog or verilator."
  exit 127
fi
