# AceCommander Tags, ContentSummary, and Token Visualizers

## Raw ContentSummary view

- **AC-VIZ-001:** Display authorized raw and normalized ContentSummary records side by side with source, producer, plugin version, content hash, Tags, asserted/recorded times, ingestion status, and synchronization state.
- **AC-VIZ-002:** Raw sensitive fields SHALL be redacted by default and revealed only through a separately authorized action.
- **AC-VIZ-003:** Parse or validation failures remain inspectable without being presented as valid summaries.

## Tag-set query view

- **AC-VIZ-010:** Present the authorized Tag universe with namespace, canonical code, active label, deprecation/retraction state, and as-of instant.
- **AC-VIZ-011:** Users SHALL select multiple Tags and choose explicit `Any` or `All` matching.
- **AC-VIZ-012:** Results SHALL show matched Tags, deterministic order, source, freshness, and provenance; the UI SHALL not imply that Tags granted access.
- **AC-VIZ-013:** Query state SHALL be serializable without embedding credentials or unauthorized result data.

## AI token timeline

- **AC-VIZ-020:** Plot request, response, and admitted additional token metrics against UTC time.
- **AC-VIZ-021:** Filters SHALL include time range, bucket size, harness, model, effort, outcome, and authorized tenant scope.
- **AC-VIZ-022:** The legend SHALL distinguish harness and model. Tooltip details SHALL show completeness, exchange count, and missing-count count.
- **AC-VIZ-023:** Missing token values SHALL not be converted to zero; partial series are visibly marked.

## Query services

The UI consumes bounded query DTOs rather than database tables. The service applies authorization before aggregation, parameterizes Tag-set membership, caps page/range size, uses stable cursor pagination, and returns a provenance/completeness envelope.
