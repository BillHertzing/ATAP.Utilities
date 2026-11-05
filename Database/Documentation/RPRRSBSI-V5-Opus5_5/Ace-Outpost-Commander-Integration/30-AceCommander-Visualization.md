# AceCommander Tags, ContentSummary, and Token Visualizers

> **V5 revision (RPRRSBSI-V5-Opus5_5, 2026-11-05).** Successor of `Database/Documentation/RPRRSBSI-V4-2-Ace-Outpost-Commander-Integration/30-AceCommander-Visualization.md`. Requirement and decision IDs keep their V4-2 numbers with the prefix `V5-` (for example `V4-2-CORE-034` is now `V5-CORE-034`); a V4-2 ID that is not repeated here is withdrawn only where the "V5 changes" section says so. The V5 decisions DEC-1 to DEC-6 and the 2026-11-05 training and gamification requirements are summarised in [the V5 overview](RPRRSBSI-V5-00-Specification-Overview.md#v5-decisions); open items are in [HANDOFF-V5.md](HANDOFF-V5.md). **Terminology (DEC-6):** an *Instantiation* is a produced file or row; the run of an executor that produces instantiations is a *Materialization*; the reusable configuration it runs is a *materialization specification*. Where carried-forward V4-2 text uses "Instantiation" for the configured act, read "materialization specification".


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
