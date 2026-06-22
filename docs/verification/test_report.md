# Test Report

Status: BLOCKED

## Summary

Rerun after RTL lint cleanup completed on 2026-06-22. RTL lint and directed simulation regression pass all tests and assertions. Overall verification signoff remains blocked because the formal flow is configured as a make target but has no available formal jobs.

## Commands

| Command | Status | Notes |
| --- | --- | --- |
| `make lint` | PASS | Ran `verible-verilog-lint` on RTL/include sources with no reported style violations. |
| `make regress` | PASS | 7/7 directed tests passed with no assertion failures. Icarus reported non-fatal `sorry` messages for constant selects and ignored `unique` qualities, plus DV-only synthesis warnings for `$display`/`$error` in procedural checks. |
| `make formal` | BLOCKED | Target is usable, but no `formal/run.sh` or `.sby` files exist under `formal/`; command exits 2 with `BLOCKED: no formal/run.sh or .sby files found under formal`. |

## Directed Tests

| Test | Status | Coverage |
| --- | --- | --- |
| `reset_x0_alu` | PASS | Reset, x0, ALU immediate, LUI, AUIPC, ECALL. |
| `alu_reg_fence` | PASS | Register ALU operations, legal FENCE NOP, EBREAK. |
| `branch_jump_link` | PASS | Branch outcomes, JAL/JALR, link registers. |
| `load_store` | PASS | Load/store widths, sign/zero extension, byte enables. |
| `trap_illegal_system` | PASS | Unsupported opcode, illegal shift, ECALL, EBREAK. |
| `trap_misaligned_data` | PASS | Misaligned load/store traps and no store on trap. |
| `trap_misaligned_control` | PASS | Misaligned branch/JAL/JALR targets and misaligned fetch PC. |

## Failures

## Assertion Results

All directed simulation tests completed without assertion failures. Active assertions covered `x0`, aligned normal fetch, trap hold, no writes during trap entry/hold, and valid store byte-enable patterns.

## Failures and Blockers

- `make formal` is blocked because no formal hook or SymbiYosys job files are present.
- No functional test, assertion, or lint failures remain from this rerun.

## Notes

- The original shell wrappers used Bash `mapfile`, which is unavailable in the default macOS Bash 3.2 environment. The wrappers were made portable so command results now reflect verification tool outcomes instead of shell compatibility failures.
- The approved spec has no ready/valid or stall/backpressure interface; backpressure verification is therefore marked not applicable in the plan.
