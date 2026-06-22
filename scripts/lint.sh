#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

RTL_FILES=()
while IFS= read -r file; do
  RTL_FILES+=("$file")
done < <(find rtl/src rtl/include -type f \( -name '*.v' -o -name '*.sv' -o -name '*.vh' -o -name '*.svh' \) 2>/dev/null | sort)

SOURCE_FILES=()
while IFS= read -r file; do
  SOURCE_FILES+=("$file")
done < <(find rtl/src -type f \( -name '*.v' -o -name '*.sv' \) 2>/dev/null | sort)

if [ "${#RTL_FILES[@]}" -eq 0 ]; then
  echo "BLOCKED: no RTL files found under rtl/src or rtl/include"
  exit 2
fi

if command -v verible-verilog-lint >/dev/null 2>&1; then
  echo "Running verible-verilog-lint"
  verible-verilog-lint "${RTL_FILES[@]}"
elif command -v verilator >/dev/null 2>&1; then
  if [ "${#SOURCE_FILES[@]}" -eq 0 ]; then
    echo "BLOCKED: no Verilog/SystemVerilog source files found under rtl/src"
    exit 2
  fi
  echo "Running verilator lint"
  verilator --lint-only --sv -Wall -Irtl/include "${SOURCE_FILES[@]}"
elif command -v iverilog >/dev/null 2>&1; then
  if [ "${#SOURCE_FILES[@]}" -eq 0 ]; then
    echo "BLOCKED: no Verilog/SystemVerilog source files found under rtl/src"
    exit 2
  fi
  echo "Running iverilog syntax check"
  iverilog -g2012 -I rtl/include -tnull "${SOURCE_FILES[@]}"
else
  echo "BLOCKED: no supported lint tool found. Install verilator, verible, or icarus-verilog."
  exit 127
fi
