# Build Folder Index

| File | Purpose |
| --- | --- |
| [Invoke-RepoHealthGate.ps1](Invoke-RepoHealthGate.ps1) | Runs repo-wide health checks outside individual package/module test flows. C# pipelines should call it after restore and before pack or publish. |
| [ATAP.Utilities.BuildTooling.current-version](ATAP.Utilities.BuildTooling.current-version) | Sentinel consumed by `Directory.Build.props` to locate the deployed MSBuild task package version. |
