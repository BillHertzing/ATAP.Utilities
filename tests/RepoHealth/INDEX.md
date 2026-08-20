# RepoHealth Test Index

| File | Purpose |
| --- | --- |
| [Directory.Build.Props.Properties.Tests.ps1](Directory.Build.Props.Properties.Tests.ps1) | Pester gate that evaluates `PackageLifeCycleStage`, `TargetProGetFeed`, and `CentralPackageVersionOverrideEnabled` through MSBuild for every C# project under `src/`. |
| [Toolchain.Baseline.Tests.ps1](Toolchain.Baseline.Tests.ps1) | Pester gate for shared invariant D01: drives `Build/Test-ToolchainBaseline.ps1` to assert the pinned SDK, its `rollForward`/`allowPrerelease` policy, the MSBuild shipped in the selected SDK, the deterministic-pack contract, and the expected workload set. Includes negative cases proving the validator fails closed. |
| [CommonBuild.Contract.Tests.ps1](CommonBuild.Contract.Tests.ps1) | Pester gate for the Task 15.180.j external-artifacts, deterministic, publication-separation, lock-validation, CPM, and BuildTooling bootstrap diagnostics. |
| [Fody.Centralization.Tests.ps1](Fody.Centralization.Tests.ps1) | Pester gate for one repository-root Fody XML, zero nested XML/XSD files, canonical payload identity, explicit opt-out, and XSD suppression. |
| [Package.SecurityGraph.Tests.ps1](Package.SecurityGraph.Tests.ps1) | Deterministic offline gate for the non-OpenHardwareMonitorLib package graph: modern ServiceStack SQL providers, lexical System.Data.SqlClient ingress detection, the intentional XML-crypto 10.0.10 pin and three direct references, reviewed prereleases, and parseable lock graphs. Downgrade enforcement belongs to the Task 15.180.n N3 bounded restore; full-repository closure remains Task 15.180.r. |
| [Configuration.ProviderNeutrality.Tests.ps1](Configuration.ProviderNeutrality.Tests.ps1) | Pester gate that keeps the `ATAP.Utilities.Configuration` aggregator provider-neutral in both its source references and checked-in lock graph. |
