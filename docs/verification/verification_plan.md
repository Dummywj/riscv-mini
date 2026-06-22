# Verification Plan

## Scope

Verify the approved `rv32i_single_cycle_cpu` RTL against `docs/spec/ip_spec.md` using directed simulation, embedded checkers, and reusable assertions. The baseline assumes single-cycle combinational instruction/data memories and no ready/valid backpressure interface.

## Strategy

- Use a self-checking SystemVerilog testbench in `dv/tb/rv32i_tb.sv` with instruction encoders, combinational memories, a byte-enable-aware store model, and hierarchical architectural register checks.
- Run directed tests listed in `dv/tests/testlist.txt` through `dv/tests/run.sh` using Icarus Verilog when available.
- Instantiate assertion collateral from `dv/assertions/rv32i_single_cycle_cpu_assertions.sv` to check architectural invariants and interface safety properties during every directed test.
- Treat trap tests as halted-state checks: after a trap, verify `trap`/`trap_cause`, held PC/trap state, no data writes, and no register writes until reset.
- Run project-level `make lint`, `make regress`, and `make formal` after RTL cleanup; document formal as unavailable if no formal hook or SymbiYosys jobs are present.

## Feature Matrix

| Area | Tests | Checks |
| --- | --- | --- |
| Reset | `reset_x0_alu` | `pc=RESET_PC`, `trap=0`, `trap_cause=NONE`, `dmem_we=0`, all integer registers zero. |
| x0 | `reset_x0_alu`, assertions | Attempted write to `x0` is ignored; assertion checks `x0==0` every active cycle. |
| ALU immediate | `reset_x0_alu` | `ADDI`, `SLTI`, `SLTIU`, `XORI`, `ORI`, `ANDI`, `SLLI`, `SRLI`, `SRAI`. |
| ALU register | `alu_reg_fence` | `ADD`, `SUB`, `SLL`, `SLT`, `SLTU`, `XOR`, `SRL`, `SRA`, `OR`, `AND`. |
| Upper immediate | `reset_x0_alu` | `LUI`, `AUIPC` write expected values. |
| Branch/jump/link | `branch_jump_link`, `trap_misaligned_control` | Branch taken/not-taken paths, `JAL`, `JALR`, link register writeback, target misalignment traps. |
| Load/store | `load_store`, `trap_misaligned_data` | `LB`, `LH`, `LW`, `LBU`, `LHU`, `SB`, `SH`, `SW`, sign/zero extension, byte lanes, data misalignment traps. |
| FENCE | `alu_reg_fence` | Legal `FENCE` executes as NOP. |
| System/trap | `trap_illegal_system` | `ECALL`, `EBREAK`, unsupported opcode, illegal shift encoding. |
| Instruction misalignment | `trap_misaligned_control` | Forced misaligned PC detects instruction-address misalignment. |
| No store on trap | `trap_misaligned_data`, assertions | Misaligned stores do not update memory; assertions suppress stores during trap entry/hold. |
| Backpressure/stall | Not applicable | Spec exposes no ready/valid, wait-state, or stall interface; memories are always-ready single-cycle. |

## Assertions

- `x0` remains zero after reset release.
- Normal fetches are word-aligned when no trap is pending.
- Trap entry and trap hold suppress data-memory writes and register writes.
- Once trapped, `trap` remains asserted and `pc` remains stable until reset.
- Store byte enables are legal and match the low address bits for `SB`, `SH`, and `SW`.

## Coverage Goals

- Hit every approved RV32I instruction in the supported subset at least once.
- Hit taken and not-taken branch behavior and both jump forms with link writes.
- Hit byte, halfword, and word load/store widths, including all byte store lanes and both halfword lanes.
- Hit sign-extension and zero-extension paths for loads.
- Hit all architecturally defined trap categories exposed by the RTL: illegal, PC misalignment, target misalignment, load misalignment, store misalignment, ECALL, and EBREAK.
- Hit reset followed by normal execution and reset followed by trap scenarios.

## Signoff Criteria

- All directed tests in `dv/tests/testlist.txt` pass.
- Assertion collateral reports no failures during directed regression.
- Available lint/syntax checks complete, or any tool limitations are documented in `docs/verification/test_report.md`.
- Formal is run when configured; if no formal jobs exist, the report records formal as BLOCKED/NOT AVAILABLE rather than a verification failure.
