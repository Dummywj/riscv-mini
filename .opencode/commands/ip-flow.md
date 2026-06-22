---
description: Run the automated digital IP development flow.
agent: ip-flow-agent
---

Run the digital IP development flow using the orchestration rules.

User input:
$ARGUMENTS

Expected behavior:
- Capture or update the requirement in `docs/requirements/user_request.md`.
- Generate or update the spec through `spec-agent` if needed.
- Stop before RTL work unless `docs/spec/approval.md` contains `Status: APPROVED`.
- After approval, coordinate RTL implementation through `rtl-agent`.
- Coordinate verification through `verify-agent`.
- Update `docs/flow/status.md` after each phase transition.
