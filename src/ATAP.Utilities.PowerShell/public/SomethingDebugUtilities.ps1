function write-NULLSortedEntryKeysString {
  param(
    [string[]] $sortedEntryKeysStrings
  )
  # any keys are null?
  $nullcount = 0
  foreach ($sortedEntryKeysString in $sortedEntryKeysStrings) {
    if (-not $sortedEntryKeysString) {
      $nullcount += 1
    }
  }
  Write-PSFMessage -Level Debug -Message "Number of NULL sortedEntryKeysString = $nullcount"
}
function Write-NullLookupKeys {
  $nullcount = 0
  foreach ($LookupKey in $([EntryKey]::Lookup).Keys) {
    if (-not $([EntryKey]::Lookup[$LookupKey])) {
      $nullcount += 1
    }
  }
  Write-PSFMessage -Level Debug -Message "Number of NULL Lookup values = $nullcount"
}

# format the entries and their dependencies into a human-readable structure
function Write-EntriesAndDependencies {
  param(
    [Parameter()]
    [Hashtable]
    $entries
  )
  foreach ($key in $entries.keys) {
    try {
      $message = "Entry at $($key): Type is $($($entries[$key].ValueToEvaluate).gettype())::: `
      ValueToEvaluate is $($entries[$key].ValueToEvaluate) ::: dependsUponParent = $($entries[$key].DependsUponParent) `
       ::: dependsUponDestination = $($entries[$key].DependsUponDestination)"
    }
    catch {
      Write-PSFMessage -Level Error -Message "Key is $key "

    }
    Write-PSFMessage -Level Debug -Message $message
  }
}

function Write-AllNodesCollection {
  $nullcount = 0

  foreach ($currentNode in $allNodesCollection) {
    if (-not $currentNode) {
      $nullcount += 1
    }
  }
  Write-PSFMessage -Level Debug -Message "Number of NULL currentNode = $nullcount"
}

function Write-DuplicateLookupKeys {
  $DuplicateLookupKeys = @{}
  $matchPatternRegex = [System.Text.RegularExpressions.Regex]::new('{{(?<collection>.*):::(?<key>.*)}}')
  foreach ($entryKeysStr in [EntryKey]::Lookup.keys) {
    $regexMatches = $matchPatternRegex.Matches($entryKeysStr)
    if ($regexMatches.Success) {
      $key = $($regexMatches.Groups).Captures | ? { $_.Name -match 'KEY' } | % { $_.Value }
      $collection = $($regexMatches.Groups).Captures | ? { $_.Name -match 'collection' } | % { $_.Value }
      if ($($DuplicateLookupKeys[$key])) {
        $DuplicateLookupKeys[$key]  += $collection
      } else {
        $DuplicateLookupKeys[$key] = @(, $collection)
      }
    }
  }

  Write-PSFMessage -Level Debug -Message "Number of Duplicate Lookup Keys = $($DuplicateLookupKeys.count) :: values are $($DuplicateLookupKeys.Keys -join ';')"
}

function Write-DependencyHash {
  foreach ($keystr in $dependencyHash.keys) {
  $part2 = $($dependencyHash[$keystr])
  # if ($($dependencyHash[$keystr]).DependsUponDestination) {
  #   # for ($index = 0; $index -lt $dependencyHash[$keystr].Count; $index++) {
  #   #   $dependentUpon = $($dependencyHash[$keystr])[$index]
  #   #   $part2 += $dependentUpon + '   '
  #   # }
  # }
  $message = "DependencyHash $keystr = $part2"
  Write-PSFMessage -Level Debug -Message $message
}
}
function Write-NULLSortedEntryKeys {
  $nullcount = 0
  foreach ($EntryKey in $sortedEntryKeys) {
    if (-not $EntryKey) {
      $nullcount += 1
    }
  }
  Write-PSFMessage -Level Debug -Message "Number of NULL EntryKeys = $nullcount"
}
