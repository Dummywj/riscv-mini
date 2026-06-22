---
name: digital-ip-flow
description: Use when developing digital IP with requirement analysis, RTL implementation, and verification agents.
---
# Digital IP Flow

Use this workflow:

1. Requirement phase:

   - Read `docs/requirements/`.
   - Generate `docs/spec/ip_spec.md`.
   - Generate `docs/spec/approval.md`, this doc should be written in Chinese.
   - Stop until the user approves the spec.
2. RTL phase:

   - Proceed only if `docs/spec/approval.md` says approved.
   - Implement RTL under `rtl/src/`.
   - Update `docs/design/micro_arch.md`.
3. Verification phase:

   - Generate verification plan.
   - Implement testbench, tests, assertions, and coverage.
   - Run available lint/simulation/formal tools when configured.
   - Generate test report.
