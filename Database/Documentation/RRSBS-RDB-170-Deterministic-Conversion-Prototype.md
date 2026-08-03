# RDB-170 — Deterministic Conversion Prototype

Status: **implemented frozen-corpus conversion and reconciliation prototype**
(2026-08-03).

## Boundary

This prototype is a deterministic, source-only mapping of the frozen RRSBS CSV
corpus to source-known target seed shapes. It does not write target seed data,
execute SQL, allocate target identities, or perform live-tier work.

## Durable result

The generated mapping at `_generated/RRSBS-V2/RDB-170/CsvConversionMapping.csv`
maps 47 CSV inputs representing 517 source rows. Two unreferenced RuleSet
inputs remain explicitly unresolved rather than being silently discarded.

`CanonicalSeedShapeMap.json` serializes the mapping in canonical order. Two
independent prototype runs produced the same SHA-256 value:

`D9D135EC626044B49720F0B40C4062880BF5A9325F7620184B6601A99C61790E`.

The frozen-input reconciliation evidence also records the source artifact
hashes: V1 `8BB6395B323C21265DCD314E0FEEF27505462936C569188AB5C3E8131EF35531`,
V2 Markdown `02719AA90E9518C4E106645DC345002425EA4B2226064A7C129E6D80DEAAC358`,
and Markdown corpus authority
`FDDE05D18E94D3B93A5FC83478A033A72E4856189030807A7A2BED82AF4B75E7`.

## Identity and reconstruction constraints

RDB-160 classifies all 334 GUID literals as `transform` source-identity
mapping inputs. Of these, 159 are reused literals whose target collision
freedom cannot be inferred from the source corpus. The prototype preserves that
ambiguity and makes no collision-free assertion.

Byte-identical target reconstruction is not yet a valid claim: the approved
target schema and identity registry do not exist. RDB-320 must perform target
identity allocation and collision proof; the Wave 3/4 implementation then must
produce the byte-identical reconstruction proof against the accepted target
model. This documented limitation is intentional, not an implicit waiver.

## Verification evidence

The reproducibility and reconciliation details are retained in
`_generated/RRSBS-V2/RDB-170/ReconciliationEvidence.md`; the generated folder
is point-in-time evidence only. This document preserves the material outcome
needed by subsequent sprint work.
