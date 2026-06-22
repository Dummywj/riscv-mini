# Toolchain

This project uses stable wrapper commands so agents do not guess local EDA tool names or vendor-specific options.

## Standard Commands

- Lint: `make lint`
- Simulation: `make sim`
- Regression: `make regress`
- Format: `make format`
- Formal: `make formal`

Agents must call standard commands only. Do not directly call vendor tools unless this file is updated to allow it.

## macOS Tool Options

Install Homebrew first if it is not installed:

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Recommended open-source tools:

- RTL lint and simulation: `brew install verilator`
- Lightweight Verilog simulation: `brew install icarus-verilog`
- SystemVerilog lint and format: `brew install chipsalliance/verible/verible`
- Waveform viewer: `brew install --cask gtkwave`
- Synthesis and formal frontend: `brew install yosys`
- SMT solvers for formal: `brew install boolector z3 yices2`
- Python verification: `python3 -m pip install --user cocotb pytest`

Optional alternatives:

- If Verible tap installation fails, try `brew install verible`.
- If GTKWave cask is unavailable on your macOS version, use Surfer or another VCD/FST viewer.
- For SymbiYosys, install from the official YosysHQ `sby` repository if your package manager does not provide it.

Commercial tools such as VCS, Questa, Xcelium, Verdi, JasperGold, and VC Formal usually do not run natively on macOS. Use a Linux workstation, server, container, or remote EDA environment for those flows.

## Tool Detection Policy

The wrapper scripts detect tools in this order:

- Lint: `verible-verilog-lint`, then `verilator`, then `iverilog`
- Format: `verible-verilog-format`
- Simulation: project-specific `sim/run.sh`, then `dv/Makefile`, then `iverilog` fallback
- Regression: project-specific `dv/tests/run.sh`, then `make sim`
- Formal: project-specific `formal/run.sh`, then `.sby` files with `sby`

If no supported tool is found, the script exits with a clear `BLOCKED` message. Agents should record that result in `docs/verification/test_report.md` instead of inventing a pass result.

## Project Rules

- Put synthesizable RTL in `rtl/src/`.
- Put shared RTL headers in `rtl/include/`.
- Put testbenches in `dv/tb/`.
- Put tests in `dv/tests/`.
- Put assertions in `dv/assertions/`.
- Put formal jobs in `formal/`.
- Put generated simulator outputs in `sim/build/`.
