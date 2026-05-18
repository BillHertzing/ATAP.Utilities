# version.json as Promotion Ceiling

**Status:** Sprint 0007 production-process requirement.

`version.json` no longer answers "which tier is this stage?" During a
BuildMaster run, the prerelease label answers "how high may this immutable
artifact be promoted?" The current stage comes from BuildMaster.

## Two Tier Concepts

| Concept | Source | Changes during one run? | Used for |
| --- | --- | --- | --- |
| `CurrentTier` | BuildMaster stage context (`$Tier`, `-Stage`, or stage environment variable) | Yes | Stage gating, test selection, source and destination feed choices |
| `CeilingTier` | NBGV prerelease label in `version.json` | No | Skipping stages above the allowed promotion ceiling |

`Get-BuildContext` now returns both values. Its legacy `.Tier` property is a
deprecated alias for `.CeilingTier` for the release that introduces this change;
callers should move to `.CeilingTier` or `.CurrentTier` explicitly.

## Ceiling Table

| `version.json` prerelease label | `CeilingTier` |
| --- | --- |
| `Sprint.N` or feature labels such as `PaymentRefactor.N` | `Experimental` |
| `Alpha` | `Development` |
| `Beta` | `Integration` |
| `QA` | `QA` |
| none | `Production` |

The documentation may still call the final public feed "stable" when referring
to ProGet feed names such as `nuget-stable`. The canonical BuildMaster tier name
in code is `Production`; `Stable` is accepted as an alias by promotion guards.

## Developer Workflow

1. Edit the relevant project or module `version.json` to set the desired
   promotion ceiling for the next immutable artifact.
2. Commit the `version.json` change with the source changes that should produce
   that candidate.
3. Trigger the BuildMaster run.
4. The Experimental stage builds and publishes exactly one artifact.
5. Later stages promote the same package bytes through feeds until
   `Test-PromotionWithinCeiling` says the next stage would exceed the ceiling.

Example: a package built from `0.1-Beta.{height}` starts in Experimental,
promotes to Development, promotes to Integration, runs the Integration gate,
and skips QA and Production. No later stage rebuilds or re-evaluates NBGV.

## Cmdlet Contract

`Get-BuildContext` returns:

- `CurrentTier`: the BuildMaster stage tier.
- `CeilingTier`: the promotion ceiling derived from `version.json`.
- `IsAtCeiling`: true when the current stage equals the ceiling.
- `Tier`: deprecated alias for `CeilingTier`.

`Test-PromotionWithinCeiling -CurrentTier <tier> -CeilingTier <tier>` is the
guard used by the Otter plans and by `Promote-ProGetPackage -CeilingTier`. It
returns `$true` for allowed promotions, and by default throws
`PromotionCeilingExceededException` before any ProGet API call when the
destination tier is above the ceiling.

See also:

- [Immutable Build Strategy](Immutable-Build-Strategy.md)
- [BuildMaster Pipeline Topology](BuildMaster-Pipeline-Topology.md)
- [C# Packages - Versioning](CSharp-Packages-Versioning.md)
- [PowerShell Modules - Versioning](PowerShell-Modules-Versioning.md)
