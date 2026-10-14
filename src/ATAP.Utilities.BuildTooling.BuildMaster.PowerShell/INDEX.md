# BuildMaster child module

Public BuildMaster automation commands are in `public/`; focused Pester tests are in
`tests/Unit/`.

| File | Purpose |
| --- | --- |
| [ReadMe.md](ReadMe.md) | Module purpose, compatibility-parent relationship, and functional-area link. |
| [ReleaseNotes.md](ReleaseNotes.md) | Published and pending behavior changes. |
| [public/New-BuildMasterApplication.ps1](public/New-BuildMasterApplication.ps1) | Idempotent BuildMaster application create/update using the supported optional-field and artifact schema. |
| [public/Compare-BuildMasterPlanRaft.ps1](public/Compare-BuildMasterPlanRaft.ps1) | Read-only metadata comparison of a deployed plan raft item against the worktree plan file: hashes, byte lengths, item id, application scope, modified dates, and stage-runner argument names. Never writes to BuildMaster and fails closed to `Unreachable` rather than `Match`. Not yet exported by the manifest, so it is reachable only by dot-sourcing. |
| [tests/Unit](tests/Unit) | Focused BuildMaster Pester coverage, including `CompareBuildMasterPlanRaft.Tests.ps1`, which mocks the HTTP boundary so no live server is contacted. |
