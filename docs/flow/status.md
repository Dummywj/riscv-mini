# IP Flow Status

Current Status: BLOCKED

Current Phase: Verification blocked

Last Updated: 2026-06-22

Inputs:
- Requirement: docs/requirements/user_request.md
- Spec: docs/spec/ip_spec.md
- Approval: docs/spec/approval.md

Outputs:
- RTL: rtl/src/
- Verification: dv/
- Test Report: docs/verification/test_report.md

Open Issues:
- `make lint` and `make regress` pass, but `make formal` is blocked because no `formal/run.sh` or `.sby` jobs exist.

Next Action:
- Add formal jobs under `formal/` or accept directed simulation plus lint as the current verification baseline.
