# RepoHealth Test Index

| File | Purpose |
| --- | --- |
| [Directory.Build.Props.Properties.Tests.ps1](Directory.Build.Props.Properties.Tests.ps1) | Pester gate that evaluates `PackageLifeCycleStage`, `TargetProGetFeed`, and `CentralPackageVersionOverrideEnabled` through MSBuild for every C# project under `src/`. |
| [Toolchain.Baseline.Tests.ps1](Toolchain.Baseline.Tests.ps1) | Pester gate for shared invariant D01: drives `Build/Test-ToolchainBaseline.ps1` to assert the pinned SDK, its `rollForward`/`allowPrerelease` policy, the MSBuild shipped in the selected SDK, the deterministic-pack contract, and the expected workload set. Includes negative cases proving the validator fails closed. |
| [CommonBuild.Contract.Tests.ps1](CommonBuild.Contract.Tests.ps1) | Pester gate for the Task 15.180.j external-artifacts, deterministic, publication-separation, lock-validation, CPM, and BuildTooling bootstrap diagnostics. |
| [Fody.Centralization.Tests.ps1](Fody.Centralization.Tests.ps1) | Pester gate for one repository-root Fody XML, zero nested XML/XSD files, canonical payload identity, explicit opt-out, and XSD suppression. |
