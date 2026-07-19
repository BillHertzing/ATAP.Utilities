function Confirm-WorktreeGitPointerOwnership {
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $WorktreePath,

    [string] $InteractiveOperator = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name,

    [bool] $RepairOwnership = $true
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"
  }

  process {
    if ([string]::IsNullOrWhiteSpace($InteractiveOperator)) {
      throw 'The interactive operator identity could not be resolved.'
    }

    $resolvedWorktreePath = [System.IO.Path]::GetFullPath($WorktreePath).TrimEnd(
      [System.IO.Path]::DirectorySeparatorChar,
      [System.IO.Path]::AltDirectorySeparatorChar
    )
    $gitPointerPath = Join-Path $resolvedWorktreePath '.git'

    if (-not (Test-Path -LiteralPath $gitPointerPath -PathType Leaf)) {
      throw "The worktree Git pointer does not exist or is not a file: '$gitPointerPath'."
    }

    $resolvedGitPointerPath = (Resolve-Path -LiteralPath $gitPointerPath -ErrorAction Stop).Path
    if (-not [string]::Equals(
        [System.IO.Path]::GetDirectoryName($resolvedGitPointerPath),
        $resolvedWorktreePath,
        [System.StringComparison]::OrdinalIgnoreCase
      )) {
      throw "Refusing ownership work outside the exact worktree Git pointer: '$resolvedGitPointerPath'."
    }

    $acl = Get-Acl -LiteralPath $resolvedGitPointerPath -ErrorAction Stop
    $ownerBefore = $acl.Owner
    $repaired = $false

    if (-not [string]::Equals($ownerBefore, $InteractiveOperator, [System.StringComparison]::OrdinalIgnoreCase)) {
      if (-not $RepairOwnership) {
        throw "Git pointer '$resolvedGitPointerPath' is owned by '$ownerBefore', not interactive operator '$InteractiveOperator'."
      }

      if ($PSCmdlet.ShouldProcess($resolvedGitPointerPath, "Set owner to interactive operator '$InteractiveOperator'")) {
        $operatorAccount = [System.Security.Principal.NTAccount]::new($InteractiveOperator)
        $acl.SetOwner($operatorAccount)
        Set-Acl -LiteralPath $resolvedGitPointerPath -AclObject $acl -ErrorAction Stop
        $repaired = $true
      }
    }

    $ownerAfter = (Get-Acl -LiteralPath $resolvedGitPointerPath -ErrorAction Stop).Owner
    if (-not [string]::Equals($ownerAfter, $InteractiveOperator, [System.StringComparison]::OrdinalIgnoreCase)) {
      throw "Git pointer ownership verification failed for '$resolvedGitPointerPath': expected '$InteractiveOperator', found '$ownerAfter'."
    }

    [PSCustomObject]@{
      WorktreePath        = $resolvedWorktreePath
      GitPointerPath      = $resolvedGitPointerPath
      InteractiveOperator = $InteractiveOperator
      OwnerBefore         = $ownerBefore
      OwnerAfter          = $ownerAfter
      Repaired            = $repaired
      Verified            = $true
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn"
  }
}
