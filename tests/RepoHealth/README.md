# RepoHealth Tests

RepoHealth tests verify repository-wide contracts that are too broad for a
single package or PowerShell module test suite.

Run them through `Build\Invoke-RepoHealthGate.ps1`. The gate currently audits
`Directory.Build.props` propagation across C# projects and should run after C#
restore and before pack or publish.
