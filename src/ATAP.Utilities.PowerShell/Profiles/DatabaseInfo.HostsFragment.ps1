$global:DatabaseProperties = @{
  'Production'  = @{
    'BuildSets' = @{
      SqlInstance           = 'utat022\SQLEXPRESS'
      ScriptDirectory       = 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.DatabaseManagement\SharedSQL'
      LoginName             = 'ProductionBuildSetsDBOwner'
      LoginPasswordVaultKey = 'ProductionBuildSetsDBPassword'
    }
  }
  'Testing'     = @{
    'BuildSets' = @{
      SqlInstance           = 'utat022\SQLEXPRESS'
      ScriptDirectory       = 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.DatabaseManagement\SharedSQL'
      LoginName             = 'TestingBuildSetsDBOwner'
      LoginPasswordVaultKey = 'TestingBuildSetsDBPassword'
    }
  }
  'Development' = @{
    'BuildSets' = @{
      SqlInstance           = 'utat022\SQLEXPRESS'
      ScriptDirectory       = 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.DatabaseManagement\SharedSQL'
      LoginName             = 'DevelopmentBuildSetsDBOwner'
      LoginPasswordVaultKey = 'DevelopmentBuildSetsDBPassword'
    }
  }
}
$global:DatabaseVaultPasswords = @{
  'Production'  = @{
    'BuildSets' = @{
      LoginPassword = "ChangeMe_!234"
    }
  }
  'Testing'     = @{
    'BuildSets' = @{
      LoginPassword = "ChangeMe_!234"
    }
  }
  'Development' = @{
    'BuildSets' = @{
      LoginPassword = "ChangeMe_!234"
    }
  }
}
