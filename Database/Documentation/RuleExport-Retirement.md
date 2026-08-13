# Rule Export retirement

Date: 2026-08-09

The pre-V3 Rule Export feature is retired. Its stored-procedure reference,
standalone query, PowerShell cmdlet, example, and focused unit test depended on
the superseded Rule and temporal result shape and are no longer active source.

The historical Flyway migration remains preserved under
`Database/Flyway/Archive/RPRRSBSI-PreV3/SQL/`. It is evidence only and must not
be copied into the active Flyway package or executed against a current database.

There is no supported replacement Rule Export API or cmdlet. A future export
feature requires a new contract based on the active RPRRSBSI V3 schema and
Philote validity semantics, followed by the normal migration, package,
rehearsal, and deployment gates.

Git history remains the recovery mechanism for the retired source and tests.
