# BuildMaster child module

Public BuildMaster automation commands are in `public/`; focused Pester tests are in
`tests/Unit/`.

| File | Purpose |
| --- | --- |
| [ReadMe.md](ReadMe.md) | Module purpose, compatibility-parent relationship, and functional-area link. |
| [ReleaseNotes.md](ReleaseNotes.md) | Published and pending behavior changes. |
| [public/New-BuildMasterApplication.ps1](public/New-BuildMasterApplication.ps1) | Idempotent BuildMaster application create/update using the supported optional-field and artifact schema. |
| [tests/Unit](tests/Unit) | Focused BuildMaster Pester coverage. |
