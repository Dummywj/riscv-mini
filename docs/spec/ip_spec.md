# IP Specification

Status: APPROVED

## IP Overview

This IP is a small single-cycle 32-bit RISC-V CPU core intended for simple FPGA/ASIC integration, bring-up, teaching, and directed verification. The core implements a practical RV32I subset sufficient for integer control-flow, arithmetic, load/store, and system-test programs while keeping the microarchitecture intentionally simple.

The CPU executes one architecturally completed instruction per clock cycle when instruction and data memories respond combinationally or within the same cycle. The core uses separate instruction and data memory interfaces and does not include caches, branch prediction, interrupts, privilege modes, debug transport, bus protocol adapters, or a memory management unit.

## Interface Definition

Top-level module name assumption: `rv32i_single_cycle_cpu`.

All signals are synchronous to `clk` unless explicitly stated otherwise.

### Clock and Reset

| Signal | Direction | Width | Description |
| --- | --- | --- | --- |
| `clk` | Input | 1 | Core clock. |
| `rst_n` | Input | 1 | Active-low reset. Reset behavior is synchronous unless implementation constraints require an asynchronous assertion/synchronous deassertion style. |

### Instruction Memory Interface

The instruction interface is a simple read-only word interface.

| Signal | Direction | Width | Description |
| --- | --- | --- | --- |
| `imem_addr` | Output | 32 | Byte address of instruction fetch. Must be word-aligned during normal execution. |
| `imem_rdata` | Input | 32 | Instruction word returned for `imem_addr`. Must be valid in the same cycle for single-cycle operation. |

Instruction memory is assumed always ready. No request, valid, ready, or error signal is included in the base interface.

### Data Memory Interface

The data interface is a simple single-cycle load/store interface.

| Signal | Direction | Width | Description |
| --- | --- | --- | --- |
| `dmem_addr` | Output | 32 | Byte address for load/store operations. |
| `dmem_wdata` | Output | 32 | Store write data before byte-lane masking. |
| `dmem_rdata` | Input | 32 | Load read data returned for `dmem_addr`. Must be valid in the same cycle for loads. |
| `dmem_we` | Output | 1 | Data memory write enable. Asserted for stores only. |
| `dmem_be` | Output | 4 | Byte write enables for stores. Also identifies active byte lanes for byte/halfword accesses. |

Data memory is assumed always ready. No wait-state, bus-error, exclusive access, atomic, or cache-control behavior is supported.

### Optional Observability Signals

These signals are recommended for verification and integration visibility. If included, they must not affect architectural behavior.

| Signal | Direction | Width | Description |
| --- | --- | --- | --- |
| `trap` | Output | 1 | Asserted when the core detects an unsupported instruction, illegal instruction encoding, instruction-address misalignment, or data-address misalignment. |
| `trap_cause` | Output | Implementation-defined, recommended 4 | Encodes trap reason for debug and verification. |
| `pc` | Output | 32 | Current fetch PC, useful for debug and trace. |

If the implementation omits optional observability signals, equivalent internal signals must be available to the verification environment.

## Register Map

This CPU core has no memory-mapped configuration or status register map.

Architectural integer register file:

| Register | ABI Name | Behavior |
| --- | --- | --- |
| `x0` | `zero` | Hard-wired to zero. Writes to `x0` are ignored. |
| `x1`-`x31` | Standard RV32I ABI aliases | 32-bit general-purpose integer registers. |

No Control and Status Registers (CSRs) are implemented in the base scope. CSR instructions are treated as unsupported/illegal unless explicitly approved in a later spec revision.

## Parameters

| Parameter | Default | Description |
| --- | --- | --- |
| `RESET_PC` | `32'h0000_0000` | Program counter value after reset release. |
| `XLEN` | `32` | Architectural data width. Fixed to 32 for RV32I; not intended to be changed. |
| `IMEM_ADDR_WIDTH` | `32` | Instruction address width exposed at the top level. May be reduced by integration wrappers only if high address bits are tied or checked. |
| `DMEM_ADDR_WIDTH` | `32` | Data address width exposed at the top level. May be reduced by integration wrappers only if high address bits are tied or checked. |
| `TRAP_ON_UNSUPPORTED` | `1` | Unsupported/illegal instructions enter trap state instead of being silently treated as NOPs. |

## Clock and Reset Behavior

- All architectural state updates occur on the rising edge of `clk`.
- While reset is asserted, the PC is set to `RESET_PC`, integer registers are initialized to zero, memory write enables are deasserted, and trap state is cleared.
- After reset is released, the first instruction fetch occurs from `RESET_PC`.
- Reset must leave the CPU in a deterministic state suitable for repeatable simulation and FPGA bring-up.
- The core has a single clock domain. No clock-domain crossing logic is included.

## Timing Assumptions

- Instruction memory is asynchronous/combinational or otherwise able to return `imem_rdata` for `imem_addr` within the same cycle.
- Data memory load data is asynchronous/combinational or otherwise able to return `dmem_rdata` for `dmem_addr` within the same cycle.
- Data memory stores commit on the active clock edge when `dmem_we` is asserted, using `dmem_be` to select byte lanes.
- Instruction and data memories are logically separate. If integrated into a shared memory, the wrapper must resolve conflicts without adding wait states unless the CPU interface is revised.
- The implementation target clock frequency is integration-dependent. The single-cycle combinational path includes instruction fetch, decode, ALU/branch address generation, optional data memory read, writeback selection, and next-PC selection.

## Functional Behavior

### Execution Model

- The CPU fetches, decodes, executes, accesses data memory when required, writes back results, and updates PC in one clock cycle per supported instruction.
- The PC increments by 4 for normal sequential instructions.
- Branch and jump targets are computed according to the RV32I specification.
- The low bit of `JALR` targets is cleared as defined by RV32I.
- Register writes occur at the clock edge. Reads of `x0` always return zero.
- If an instruction writes `x0`, the write is ignored and no architectural state changes for `x0` occur.

### Supported Instruction Set

The base scope supports the following RV32I user-level integer instructions:

| Type | Instructions | Notes |
| --- | --- | --- |
| Upper immediate | `LUI`, `AUIPC` | Standard RV32I immediate behavior. |
| Jump | `JAL`, `JALR` | Writes `pc + 4` to `rd`; supports unaligned target detection as described in error handling. |
| Branch | `BEQ`, `BNE`, `BLT`, `BGE`, `BLTU`, `BGEU` | Signed/unsigned comparisons per opcode. |
| Load | `LB`, `LH`, `LW`, `LBU`, `LHU` | Byte/halfword loads sign- or zero-extend to 32 bits. |
| Store | `SB`, `SH`, `SW` | Uses `dmem_be` for byte lane selection. |
| Immediate ALU | `ADDI`, `SLTI`, `SLTIU`, `XORI`, `ORI`, `ANDI`, `SLLI`, `SRLI`, `SRAI` | Shift amounts use instruction bits `[24:20]`; illegal shift encodings trap. |
| Register ALU | `ADD`, `SUB`, `SLL`, `SLT`, `SLTU`, `XOR`, `SRL`, `SRA`, `OR`, `AND` | Standard RV32I register-register behavior. |
| Memory ordering | `FENCE` | Treated as a legal NOP because the base core is in-order, single-cycle, and has no cache or outstanding transactions. |
| System | `ECALL`, `EBREAK` | Treated as legal trap-generating instructions. |

### Unsupported Instruction Scope

The following are out of scope unless approved in a later revision:

- RISC-V `M`, `A`, `F`, `D`, `C`, `Zicsr`, `Zifencei`, vector, bit-manipulation, and privileged extensions.
- Interrupts, exceptions with full privileged trap handling, CSRs, `mret`, and privilege levels.
- Misaligned load/store emulation.
- Pipeline hazards, forwarding, stalls, branch prediction, caches, debug module, and bus protocol adapters.

### Load and Store Details

- `LW` requires `dmem_addr[1:0] == 2'b00`.
- `LH`/`LHU` require `dmem_addr[0] == 1'b0`.
- `LB`/`LBU` may access any byte address.
- `SW` requires `dmem_addr[1:0] == 2'b00` and asserts all byte enables.
- `SH` requires `dmem_addr[0] == 1'b0` and asserts the selected two byte lanes.
- `SB` may access any byte address and asserts one byte lane.
- Loads align returned data according to `dmem_addr[1:0]` and apply sign/zero extension as required by instruction type.

### Trap Behavior

- When `trap` is asserted, the CPU enters a halted trap state and stops retiring further instructions until reset.
- In trap state, memory writes remain deasserted and architectural register state is held.
- For `ECALL` and `EBREAK`, the trap state is entered after decoding the instruction; no CSR side effects are required.
- No trap vector, `mcause`, `mepc`, or return-from-trap mechanism is included in this draft scope.

## Error Handling

The core must detect and trap on:

- Unsupported or illegal instruction encodings.
- Unsupported extension instructions, including CSR and multiply/divide instructions.
- Instruction fetch address misalignment when `pc[1:0] != 2'b00`.
- Taken branch/jump target misalignment when the computed target is not word-aligned.
- Misaligned `LH`, `LHU`, `LW`, `SH`, or `SW` data accesses.
- `ECALL` and `EBREAK` instructions.

The core must not assert `dmem_we` for illegal, unsupported, trapped, or misaligned store instructions. Error reporting beyond `trap`/`trap_cause` is optional unless integration requirements define a bus error interface.

## Performance Requirements

- Supported instructions retire in one clock cycle when memories meet the single-cycle timing assumptions.
- CPI is 1.0 for straight-line supported code with zero wait states.
- Taken branches and jumps have no additional branch penalty in the single-cycle model.
- No throughput guarantee is made if external wrappers add wait states, arbitration, or shared-memory conflicts.
- Area should remain small and suitable for educational or lightweight embedded use; therefore multi-cycle multiply/divide, caches, and full privileged architecture are excluded.

## Verification Requirements

Verification must demonstrate that the approved specification is implemented correctly before RTL signoff.

Minimum required verification content:

- Directed instruction tests for every supported RV32I instruction listed in this spec.
- Register file tests covering writes, read-after-write behavior within the selected register-file implementation model, and ignored writes to `x0`.
- Branch and jump tests covering taken/not-taken branches, positive and negative immediates, `JAL`, `JALR`, and link register writeback.
- Load/store tests covering byte, halfword, word, sign extension, zero extension, byte enables, and address offsets.
- Misalignment and unsupported-instruction tests proving the core enters trap state and suppresses unsafe memory writes.
- Reset tests proving deterministic PC, register file, trap, and memory write-enable state.
- Reference-model or scoreboard comparison against architectural expected state for directed programs.
- Functional coverage for opcode groups, branch outcomes, load/store widths, byte lanes, trap causes, and representative immediate encodings.
- Assertions for `x0 == 0`, aligned instruction fetch during normal operation, no data write during trap, stable halted state in trap, and valid byte-enable patterns for stores.

Optional but recommended:

- RV32I compliance-style tests adapted for the supported no-CSR/no-privilege environment.
- Random instruction streams constrained to supported instructions and valid memory regions.
- Simple synthesis or lint check to confirm the design remains combinationally single-cycle without inferred latches.

## Open Questions

The following assumptions are accepted for this approved baseline unless superseded by a later spec revision:

1. Should reset be strictly synchronous, or should asynchronous assertion/synchronous deassertion be required?
2. Is `RESET_PC = 32'h0000_0000` acceptable, or is another boot address required?
3. Should optional `trap`, `trap_cause`, and `pc` observability signals be mandatory top-level ports?
4. Should `FENCE.I` be unsupported/trapping, or treated as a legal NOP like `FENCE`?
5. Should the design support any CSR subset such as `mcycle`, `minstret`, `mtvec`, `mepc`, or `mcause`?
6. Should trapped execution halt until reset, or should a trap-vector mechanism be added?
7. Are instruction and data memories required to be little-endian? This draft assumes little-endian RV32I behavior.
8. Are there target frequency, area, synthesis technology, or FPGA family constraints?
9. Should reduced address-width top-level ports be used instead of full 32-bit addresses?
10. Should instruction/data memory interfaces include ready/valid handshaking for non-single-cycle memories?

## Approval Status

APPROVED. This specification is the approved baseline for RTL implementation and verification.
