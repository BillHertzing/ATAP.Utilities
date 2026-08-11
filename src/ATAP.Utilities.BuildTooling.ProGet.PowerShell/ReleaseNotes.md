# Release notes

## 0.1.8

- Add the narrowly typed `register-atap-parity-tasks` elevation-broker installer. It accepts only an exact installed SystemParityMonitor version and may repoint only the approved local parity tasks.

## 0.1.1

- Corrected the ProGet administration boundary test to use Pester mocks when
  the packaged module and its Secrets dependency are already imported.
- Version 0.1.0 was burned after its Development promoted-package gate exposed
  the test-isolation defect.

## 0.1.0

- Extracted the ProGet feed-administration, publication, promotion, and
  package-retrieval implementation from the aggregate BuildTooling module.
- Added explicit 36-command exports and 320 focused unit/integration tests.
- Retained the aggregate module as the compatibility surface.
