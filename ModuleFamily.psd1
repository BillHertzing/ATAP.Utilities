@{
  SchemaVersion = '1.0'
  FamilyName = 'ATAP.Utilities.BuildTooling'
  BootstrapModule = 'ATAP.Utilities.BuildTooling.PowerShell'
  BuildOrder = @(
    'ATAP.Utilities.BuildTooling.Common.PowerShell'
    'ATAP.Utilities.BuildTooling.PesterScaffolding.PowerShell'
    'ATAP.Utilities.BuildTooling.GitWorktree.PowerShell'
    'ATAP.Utilities.BuildTooling.PlanningSession.PowerShell'
    'ATAP.Utilities.BuildTooling.AiRendering.PowerShell'
    'ATAP.Utilities.BuildTooling.Secrets.PowerShell'
    'ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell'
    'ATAP.Utilities.BuildTooling.DatabasePackaging.PowerShell'
    'ATAP.Utilities.BuildTooling.ProGet.PowerShell'
    'ATAP.Utilities.BuildTooling.BuildMaster.PowerShell'
    'ATAP.Utilities.BuildTooling.DotnetBuild.PowerShell'
    'ATAP.Utilities.BuildTooling.PowerShell'
  )
  Defaults = @{
    PowerShellVersion = '7.0'
    CompatiblePSEditions = @('Core')
    BuildMasterApplication = 'ATAP.Utilities-PowerShell'
  }
  Members = @(
    @{ Name = 'ATAP.Utilities.BuildTooling.Common.PowerShell'; Guid = 'E5188E6B-F4DE-451B-9EC1-D8E5DD15A6FD'; Dependencies = @(); MinimumVersions = @{} }
    @{ Name = 'ATAP.Utilities.BuildTooling.PesterScaffolding.PowerShell'; Guid = 'C986DA8E-1854-4A9A-8D3F-9AE97E65A3AC'; Dependencies = @('ATAP.Utilities.BuildTooling.Common.PowerShell'); MinimumVersions = @{ 'ATAP.Utilities.BuildTooling.Common.PowerShell' = '0.1.5' } }
    @{ Name = 'ATAP.Utilities.BuildTooling.GitWorktree.PowerShell'; Guid = '1E070AD5-6431-4C3E-B7E6-BC69B9CD5AF3'; Dependencies = @('ATAP.Utilities.BuildTooling.Common.PowerShell'); MinimumVersions = @{ 'ATAP.Utilities.BuildTooling.Common.PowerShell' = '0.1.5' } }
    @{ Name = 'ATAP.Utilities.BuildTooling.PlanningSession.PowerShell'; Guid = '80EB57AE-F4E4-4473-8B87-FCD3A51A5629'; Dependencies = @('ATAP.Utilities.BuildTooling.Common.PowerShell'); MinimumVersions = @{ 'ATAP.Utilities.BuildTooling.Common.PowerShell' = '0.1.0' } }
    @{ Name = 'ATAP.Utilities.BuildTooling.AiRendering.PowerShell'; Guid = '60F43986-75BD-4E00-9B62-0DAF59263697'; Dependencies = @('ATAP.Utilities.BuildTooling.Common.PowerShell'); MinimumVersions = @{ 'ATAP.Utilities.BuildTooling.Common.PowerShell' = '0.1.0' } }
    @{ Name = 'ATAP.Utilities.BuildTooling.Secrets.PowerShell'; Guid = 'FC569DA2-E693-4E23-946E-2EE9F82BA43E'; Dependencies = @('ATAP.Utilities.BuildTooling.Common.PowerShell'); MinimumVersions = @{ 'ATAP.Utilities.BuildTooling.Common.PowerShell' = '0.1.0' } }
    @{ Name = 'ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell'; Guid = '7B1D7C2B-D54C-473B-B7A5-0A70BBD67AFB'; Dependencies = @('ATAP.Utilities.BuildTooling.Common.PowerShell'); MinimumVersions = @{ 'ATAP.Utilities.BuildTooling.Common.PowerShell' = '0.1.0' } }
    @{ Name = 'ATAP.Utilities.BuildTooling.DatabasePackaging.PowerShell'; Guid = 'F2681E48-6015-42D6-9D16-F2308CE7DE1A'; Dependencies = @('ATAP.Utilities.BuildTooling.Common.PowerShell'); MinimumVersions = @{ 'ATAP.Utilities.BuildTooling.Common.PowerShell' = '0.1.0' } }
    @{ Name = 'ATAP.Utilities.BuildTooling.ProGet.PowerShell'; Guid = '35EE8B2A-E1D7-4668-8B4A-A6E9F5767303'; Dependencies = @('ATAP.Utilities.BuildTooling.Common.PowerShell'); MinimumVersions = @{ 'ATAP.Utilities.BuildTooling.Common.PowerShell' = '0.1.0' } }
    @{ Name = 'ATAP.Utilities.BuildTooling.BuildMaster.PowerShell'; Guid = '4196BC5E-7545-42A1-8BFD-CF3D0C5FD72E'; Dependencies = @('ATAP.Utilities.BuildTooling.Common.PowerShell'); MinimumVersions = @{ 'ATAP.Utilities.BuildTooling.Common.PowerShell' = '0.1.0' } }
    @{ Name = 'ATAP.Utilities.BuildTooling.DotnetBuild.PowerShell'; Guid = 'A2B1C552-FD36-4DCE-92B8-0A76BD4FA92F'; Dependencies = @('ATAP.Utilities.BuildTooling.Common.PowerShell'); MinimumVersions = @{ 'ATAP.Utilities.BuildTooling.Common.PowerShell' = '0.1.0' } }
    @{ Name = 'ATAP.Utilities.BuildTooling.PowerShell'; Guid = 'DBD8663F-C30C-4702-B97A-5365529B4D15'; Dependencies = @('ATAP.Utilities.BuildTooling.PesterScaffolding.PowerShell', 'ATAP.Utilities.BuildTooling.GitWorktree.PowerShell'); MinimumVersions = @{ 'ATAP.Utilities.BuildTooling.PesterScaffolding.PowerShell' = '0.1.1'; 'ATAP.Utilities.BuildTooling.GitWorktree.PowerShell' = '0.1.0' } }
  )
}
