function Repair-AISupervisorV00150Newlines {
  <#
  .SYNOPSIS
  Restores V00150's CRLF predecessor contract without changing immutable migrations.
  .DESCRIPTION
  For the authorized local developer instances only, compares the complete capture
  procedure with canonical V00070 after newline normalization. Changes only line
  endings in that exact predecessor definition. Does not migrate or repair history.
  Already-applied V00150 is a no-op. Run installed Flyway separately afterward.
  .PARAMETER SqlConnection
  An open Microsoft.Data.SqlClient connection to ATAPUtilities on a local Dev/Exp instance.
  .PARAMETER PredecessorMigrationPath
  Exact canonical V00070 migration, whose immutable SHA-256 is verified.
  .OUTPUTS
  PSCustomObject containing the target and Changed/AlreadyApplied state.
  .EXAMPLE
  Repair-AISupervisorV00150Newlines -SqlConnection $connection -PredecessorMigrationPath $v70 -Confirm:$false
  .NOTES
  Operator recovery only; no source package changes or history checksum repair.
  .LINK
  ../../Documentation/V00150-Newline-Recovery.md
  #>
  [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
  param(
    [Parameter(Mandatory)]
    [object]$SqlConnection,
    [Parameter(Mandatory)]
    [string]$PredecessorMigrationPath
  )
  begin {
    $fn = 'Repair-AISupervisorV00150Newlines'
    $mn = 'ATAPUtilities.DatabaseRecovery'
    if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
      Import-Module PSFramework -ErrorAction Stop
    }
    $authorizedTargetPattern = '^(localhost|\.|' + [regex]::Escape($env:COMPUTERNAME) + ')\\(Devwhertzing|Expwhertzing)$'
    if ($SqlConnection.GetType().FullName -ne 'Microsoft.Data.SqlClient.SqlConnection' -or
        $SqlConnection.State -ne [Data.ConnectionState]::Open -or
        $SqlConnection.Database -cne 'ATAPUtilities' -or
        $SqlConnection.DataSource -notmatch $authorizedTargetPattern) {
      throw 'Requires an open ATAPUtilities connection to an explicitly authorized local Dev/Exp instance.'
    }
    $source = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $PredecessorMigrationPath).Path)
    $source = $source.Replace("`r`n", "`n").Replace("`r", "`n")
    $sourceHash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.UTF8Encoding]::new($false).GetBytes($source)))
    if ($sourceHash -cne '887006D66FD6519FFC840552B798BDD159CBDEF322BF82BC418F552CDAF3524C') {
      throw 'Canonical V00070 hash mismatch; refusing recovery.'
    }
    $literal = [regex]::Match($source, "EXEC sys\.sp_executesql N'(CREATE PROCEDURE \[Ace\]\.\[CaptureAISupervisorAttempt\](?:''|[^'])*)';")
    if (-not $literal.Success) { throw 'Canonical capture procedure literal not found.' }
    $expected = $literal.Groups[1].Value.Replace("''", "'").Replace("`r`n", "`n").Replace("`r", "`n")
  }
  process {
    $command = $SqlConnection.CreateCommand()
    try {
      $command.CommandText = @'
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
  BEGIN TRANSACTION;
  IF EXISTS (SELECT 1 FROM dbo.flyway_schema_history WHERE TRY_CONVERT(int,version)=150 AND success=1)
  BEGIN
    COMMIT;
    SELECT N'AlreadyApplied' AS Status;
    RETURN;
  END;
  IF EXISTS (SELECT 1 FROM dbo.flyway_schema_history WHERE success=0)
     OR NOT EXISTS (SELECT 1 FROM dbo.flyway_schema_history WHERE TRY_CONVERT(int,version)=140 AND success=1)
     OR COL_LENGTH(N'Ace.AISupervisorUsage',N'CacheTokens') IS NOT NULL
    THROW 60620, N'Requires successful V00140 and unapplied V00150 without failed history.', 1;
  DECLARE @definition nvarchar(max)=OBJECT_DEFINITION(OBJECT_ID(N'Ace.CaptureAISupervisorAttempt',N'P'));
  IF LEFT(@definition,LEN(N'ALTER PROCEDURE [Ace].[CaptureAISupervisorAttempt]')) COLLATE Latin1_General_100_BIN2
       = N'ALTER PROCEDURE [Ace].[CaptureAISupervisorAttempt]' COLLATE Latin1_General_100_BIN2
    SET @definition=STUFF(@definition,1,LEN(N'ALTER'),N'CREATE');
  DECLARE @lf nvarchar(max)=REPLACE(REPLACE(@definition,NCHAR(13)+NCHAR(10),NCHAR(10)),NCHAR(13),NCHAR(10));
  IF @lf IS NULL OR DATALENGTH(@lf)<>DATALENGTH(@Expected)
     OR @lf COLLATE Latin1_General_100_BIN2 <> @Expected COLLATE Latin1_General_100_BIN2
    THROW 60621, N'Complete canonical V00070 capture definition mismatch; refusing recovery.', 1;
  DECLARE @crlf nvarchar(max)=REPLACE(@lf,NCHAR(10),NCHAR(13)+NCHAR(10));
  IF @definition COLLATE Latin1_General_100_BIN2 = @crlf COLLATE Latin1_General_100_BIN2
  BEGIN
    COMMIT;
    SELECT N'Unchanged' AS Status;
    RETURN;
  END;
  IF @Apply=0
  BEGIN
    COMMIT;
    SELECT N'WouldChange' AS Status;
    RETURN;
  END;
  IF EXISTS (SELECT 1 FROM sys.sql_modules WHERE object_id=OBJECT_ID(N'Ace.CaptureAISupervisorAttempt',N'P')
             AND (uses_ansi_nulls<>CONVERT(bit,SESSIONPROPERTY('ANSI_NULLS'))
                  OR uses_quoted_identifier<>CONVERT(bit,SESSIONPROPERTY('QUOTED_IDENTIFIER'))))
    THROW 60624, N'Session SET options differ from predecessor module; refusing metadata change.', 1;
  IF LEFT(@crlf,LEN(N'CREATE PROCEDURE [Ace].[CaptureAISupervisorAttempt]')) COLLATE Latin1_General_100_BIN2
       <> N'CREATE PROCEDURE [Ace].[CaptureAISupervisorAttempt]' COLLATE Latin1_General_100_BIN2
    THROW 60622, N'Unexpected CREATE prefix.', 1;
  DECLARE @alter nvarchar(max)=STUFF(@crlf,1,LEN(N'CREATE'),N'ALTER');
  EXEC sys.sp_executesql @alter;
  -- Accept SQL Server's CREATE/ALTER metadata representation of the same definition.
  DECLARE @after nvarchar(max)=OBJECT_DEFINITION(OBJECT_ID(N'Ace.CaptureAISupervisorAttempt',N'P'));
  IF LEFT(@after,LEN(N'ALTER PROCEDURE [Ace].[CaptureAISupervisorAttempt]')) COLLATE Latin1_General_100_BIN2
       = N'ALTER PROCEDURE [Ace].[CaptureAISupervisorAttempt]' COLLATE Latin1_General_100_BIN2
    SET @after=STUFF(@after,1,LEN(N'ALTER'),N'CREATE');
  IF DATALENGTH(@after)<>DATALENGTH(@crlf) OR @after COLLATE Latin1_General_100_BIN2 <> @crlf COLLATE Latin1_General_100_BIN2
  BEGIN
    DECLARE @error nvarchar(2048)=CONCAT(N'Newline recovery postcondition failed. Actual bytes=',DATALENGTH(@after),N'; expected bytes=',DATALENGTH(@crlf),N'; prefix=',LEFT(@after,60));
    THROW 60623, @error, 1;
  END;
  COMMIT;
  SELECT N'Changed' AS Status;
END TRY
BEGIN CATCH
  IF XACT_STATE()<>0 ROLLBACK;
  THROW;
END CATCH;
'@
      [void]$command.Parameters.Add('@Expected', [Data.SqlDbType]::NVarChar, -1)
      $command.Parameters['@Expected'].Value = $expected
      [void]$command.Parameters.Add('@Apply', [Data.SqlDbType]::Bit)
      $apply = $PSCmdlet.ShouldProcess($SqlConnection.DataSource, 'Normalize canonical V00070 capture definition to CRLF for pending V00150')
      $command.Parameters['@Apply'].Value = $apply
      $status = [string]$command.ExecuteScalar()
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "V00150 newline recovery: $status on $($SqlConnection.DataSource)"
      [pscustomobject]@{ Server=$SqlConnection.DataSource; Database=$SqlConnection.Database; Status=$status; Changed=($status -eq 'Changed') }
    } finally {
      $command.Dispose()
    }
  }
  end { }
}
