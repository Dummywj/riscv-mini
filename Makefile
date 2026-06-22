SHELL := /bin/bash

.PHONY: help lint sim regress format formal clean

help:
	@echo "Available targets:"
	@echo "  make lint     - Run RTL lint with the first available supported tool"
	@echo "  make sim      - Run simulation through the standard wrapper"
	@echo "  make regress  - Run regression through the standard wrapper"
	@echo "  make format   - Format RTL with verible-verilog-format"
	@echo "  make formal   - Run formal checks when configured"
	@echo "  make clean    - Remove generated simulation outputs"

lint:
	@scripts/lint.sh

sim:
	@scripts/sim.sh

regress:
	@scripts/regress.sh

format:
	@scripts/format.sh

formal:
	@scripts/formal.sh

clean:
	@rm -rf sim/build
