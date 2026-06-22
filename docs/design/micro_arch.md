# Micro Architecture

## Overview

The RTL implements the approved `rv32i_single_cycle_cpu` as a compact single-cycle RV32I subset core. Instruction fetch, decode, execute, optional data memory access, writeback selection, and next-PC selection are all combinational within one cycle; architectural state updates occur on the rising edge of `clk`.

## Top-Level Interface

- Module: `rv32i_single_cycle_cpu`.
- Source: `rtl/src/rv32i_single_cycle_cpu.sv`.
- Shared definitions: `rtl/include/rv32i_defs.svh`.
- Memory model: separate combinational/same-cycle instruction and data memory interfaces with no ready/valid handshaking.
- Observability: `trap`, `trap_cause`, and `pc` are mandatory top-level outputs for verification visibility.

## Architectural State

- `pc_q`: current fetch PC, reset to `RESET_PC`.
- `regs_q[31:0]`: 32-entry integer register file, reset to zero; `x0` is forced to zero and writes to `x0` are ignored.
- `trap_q`: sticky halted-trap state, cleared only by reset.
- `trap_cause_q`: 4-bit implementation-defined trap reason code.

Reset is active-low and synchronous to `clk`. While reset is asserted, PC, register file, trap state, and trap cause are deterministic.

## Datapath and Control

The core uses direct decode of opcode, `funct3`, and `funct7` fields from `imem_rdata`. Immediate values are generated for I, S, B, U, and J formats. A shared adder computes PC-relative and register-relative targets. ALU operations are implemented with synthesizable SystemVerilog operators.

Supported instruction groups are:

- Upper immediates: `LUI`, `AUIPC`.
- Control flow: `JAL`, `JALR`, and conditional branches.
- Loads/stores: `LB`, `LH`, `LW`, `LBU`, `LHU`, `SB`, `SH`, `SW`.
- Integer ALU: approved RV32I immediate and register-register operations.
- Ordering/system: `FENCE` as legal NOP; `ECALL` and `EBREAK` enter trap.

`FENCE.I`, CSR instructions, multiply/divide, atomics, compressed instructions, privileged instructions, and all other unsupported encodings trap as illegal instructions.

## Memory Accesses

Data memory address generation uses `rs1 + immediate`. Loads select bytes or halfwords from `dmem_rdata` according to `dmem_addr[1:0]` and apply sign or zero extension. Stores drive lane-aligned byte, halfword, or word data on `dmem_wdata` and select active byte lanes with `dmem_be`.

Store write enable is purely combinational for the current instruction and is suppressed whenever the core is already trapped, the current instruction traps, or a store address is misaligned.

## Trap Handling

The core enters a halted trap state on:

- Illegal or unsupported instruction encodings.
- Misaligned fetch PC.
- Misaligned taken branch or jump target.
- Misaligned `LH`, `LHU`, `LW`, `SH`, or `SW` access.
- `ECALL` or `EBREAK`.

On a trap-causing instruction, register writeback, store writes, and PC advance are suppressed. In halted trap state, PC, register state, and trap cause are held until reset, and data memory writes remain deasserted.

Trap cause encodings are defined in `rtl/include/rv32i_defs.svh`:

| Code | Meaning |
| --- | --- |
| `4'h0` | No trap |
| `4'h1` | Illegal/unsupported instruction |
| `4'h2` | Fetch PC misaligned |
| `4'h3` | Taken branch/jump target misaligned |
| `4'h4` | Load address misaligned |
| `4'h5` | Store address misaligned |
| `4'h6` | `ECALL` |
| `4'h7` | `EBREAK` |

## Implementation Notes

- The RTL is intentionally single-module except for shared macro definitions.
- Parameters match the approved spec defaults: `RESET_PC`, `XLEN`, `IMEM_ADDR_WIDTH`, `DMEM_ADDR_WIDTH`, and `TRAP_ON_UNSUPPORTED`.
- `XLEN` is present for interface/spec traceability; the implementation is fixed to RV32I 32-bit datapaths.
- Memories are assumed little-endian and same-cycle responsive per the approved specification.
