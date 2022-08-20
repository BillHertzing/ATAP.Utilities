
# Many settings are defined in terms of other settings. Settings' values must be evaulated in such an order that earlier settings are evaulated before dependent settings.
# settings that are defined in terms of other settings are discovered by analysis of the destination.
class CompoundID {
  [guid] $CollectionID
  # only string and int are supported
  [object] $Key
  CompoundID(
    [guid] $CollectionID
    , [object] $Key
  ) {
    $this.CollectionID = $CollectionID
    $this.Key = $Key

  }
  # using a static would result in concurrency errors, unless it is made threadsafe
  # [System.Text.StringBuilder] hidden $keySB;
  [string] ToString([string] $stringSeperator) {

    #$null = $keySB.Clear()
    # $null = $keySB.Append('{')
    # $null = $keySB.Append($this.CollectionID)
    # $null = $keySB.Append($stringSeperator)
    # $null = $keySB.Append($this.Key)
    # $null = $keySB.Append('}')
    # $keySB.ToString()
    return '{' + $this.CollectionID.ToString() + $stringSeperator + $this.key.ToString() + '}'
  }
}

function Get-SomethingCatchy {
  [CmdletBinding(DefaultParameterSetName = 'Hashtables')]
  param (
    [Parameter(Mandatory = $true)]
    [object[]]
    $sourceCollections
    , [Parameter(Mandatory = $true)]
    [hashtable]
    $destination
    , [Parameter()]
    [System.Text.RegularExpressions.Regex]
    $matchPatternRegex
    , [Parameter()]
    [string]
    $hashElementStringSeperator = ':::'
  )
  $DebugPreference = 'Continue'
  . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Powershell\public\Get-ClonedObject.ps1'
  . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Powershell\public\Get-TopologicalSort.ps1'

  $collections = @{}
  $entries = @{}
  $dependencyHash = @{}

  $keySB = New-Object System.Text.StringBuilder

  # $hashElementStringSeperatorLength = $hashElementStringSeperator.Length

  # The ToString method for a CompoundID object
  function CompoundIDToString {
    param (
      [Parameter()]
      [object]
      $compoundID
    )
    $null = $keySB.Clear()
    $null = $keySB.Append('{')
    $null = $keySB.Append($compoundID.CollectionID)
    $null = $keySB.Append($hashElementStringSeperator)
    $null = $keySB.Append($compoundID.KeyID)
    $null = $keySB.Append('}')
    $keySB.ToString()
  }
  $fromStringRegex = [regex] $('{(?<CollectionID>.*?)' + $hashElementStringSeperator + '(?<KeyID>.*?)}')
  function CompoundIDFromString {
    param (
      [Parameter()]
      [string]
      $str
    )
    if ($str -match $fromStringRegex) {
      # Have to get the actual object, not a new object made with same-value properties
      foreach ($compoundID in $entries.keys) {
        if (($compoundID.KeyID -eq $matches['KeyID']) -and ($compoundID.CollectionID -eq $matches['CollectionID'])) {
          return $compoundID
        }
      }
    }
    else { throw }
    throw
  }

  # Create an entry that creates a subordinatecollection:
  function CreateSubordinateCollectionEntry {
    [CmdletBinding()]
    param (
      [Parameter()]
      [object]
      $parentCompoundID
    )
    $childEntryCompoundID = @{
      CollectionID = $parentCompoundID.CollectionID
      KeyID        = $parentCompoundID.KeyID
    }
    switch ($($($collections[$parentCompoundID.CollectionID]).Collection[$parentCompoundID.KeyID]).GetType().fullname) {
      'System.Collections.Hashtable' {
        $valueToEvaluate = @{}
      }
      'System.Object[]' {
        $valueToEvaluate = @()
      }
      default {
        throw
      }
    }

    $entries[$childEntryCompoundID] = @{
      # This records an instruction to create the empty child collection in the parent's collection at the key of the original child collection
      ValueToEvaluate = $valueToEvaluate
    }
    # The entry that creates the child collection depends upon anything that the parent entry might depend upon
    if ($($entries[$parentCompoundID])) {
      if ($($entries[$parentCompoundID])['DependsUpon']) {
        # The the parent collection has dependencies
        $($entries[$childEntryCompoundID])['DependsUpon'] = $($entries[$parentCompoundID])['DependsUpon']
      }
    }

  }

  # Create an entry in the $collections hash
  #  If a ParentCompoundID is passed, create an entry in the $entries hash that creates the collectionin the $destination hash
  function CreateCollection {
    [CmdletBinding(DefaultParameterSetName = 'NoParent')]
    param (
      [Parameter()]
      [guid]
      $collectionID
      , [Parameter()]
      [object]
      $collection
      , [Parameter(ParameterSetName = 'HasParent')]
      [object]
      $parentCompoundID
    )
    # Passing $null for parentCompoundID indicates a top-level Source hash is being processed
    switch ($PsCmdlet.ParameterSetName) {
      'NoParent' {
        Write-PSFMessage -Level Debug -Message "NoParent collectionID = $collectionID "
        $collections[$collectionID] = @{
          Collection = $collection
        }
      }
      'HasParent' {
        Write-PSFMessage -Level Debug -Message "HasParent collectionID = $collectionID : ParentCollectionID = $($parentCompoundID.CollectionID) : parentKeyID = $($parentCompoundID.KeyID)"
        $collections[$collectionID] = @{
          # Passing $null for parentCompoundID indicates a top-level Source hash is being processed
          ParentCompoundID = $parentCompoundID
          Collection       = $collection
        }
      }
    }
  }

  function CreateEntries {
    [CmdletBinding(DefaultParameterSetName = 'Hashtable')]
    param (
      [Parameter()]
      [object]
      $collectionID
      , [Parameter(ParameterSetName = 'Hashtable')]
      [object]
      $keyID
      , [Parameter(ParameterSetName = 'Array')]
      [object]
      $index
    )
    # calculating the u->v dependencies. This entry is a vertice (V) node
    #  dependsUpon starts as null
    $dependsUpon = $null
    switch ($PsCmdlet.ParameterSetName) {
      'Hashtable' {
        Write-PSFMessage -Level Debug -Message "Hashtable collectionID = $collectionID : keyID = $keyID : ValueToEvaluate = $($collections[$collectionID].Collection[$keyID])"
        # Create the compoundKey used to identify this entry in the $entries hash
        $compoundID = @{
          CollectionID = $collectionID
          KeyID        = $keyID
        }
        # Create this entry in the $entries hash
        $entries[$compoundID] = @{
          ValueToEvaluate = $collections[$collectionID].Collection[$keyID]
        }

      }
      'Array' {
        Write-PSFMessage -Level Debug -Message "Array collectionID = $collectionID : index = $index : ValueToEvaluate = $($collections[$collectionID].Collection[$index])"
        # Create the compoundKey used to identify this entry in the $entries hash
        $compoundID = @{
          CollectionID = $collectionID
          KeyID        = $index
        }
        # Create this entry in the $entries hash
        $entries[$compoundID] = @{
          ValueToEvaluate = $collections[$collectionID].Collection[$index]
        }
        $keyID = $index
      }
    }

    # If the collection to which v belongs has no parents, this entry does not depend upon a parent collection.
    # But if the collection to which v belongs does have a parent collection, then this entry v dependsUpon the parent, specifically the KeyID of the parent entry
    if ($collections[$collectionID].ContainsKey('ParentCompoundID')) {
      $dependsUpon = @{Parent = $collections[$collectionID].ParentCompoundID }
      #$dependsUpon = @(, @{CollectionID = $collections[$collectionID].ParentCompoundID.CollectionID ; MatchArray = @($collections[$collectionID].ParentCompoundID.KeyID) })
    }

    # does this value of this entry v reference another node? (the match pattern provides one or more pattern-extracted substrings)
    $regexMatches = $matchPatternRegex.Matches($collections[$collectionID].Collection[$KeyID])
    if ($regexMatches.Success) {
      # This algorithm only allows for references to nodes in the destination collection
      # the destination collection ID is always $null
      # the value of this entry depends on at least one other node u (a destination collection setting)
      # Process a string contains one or more nodes u (dependencies)
      #  the .Matches() method of a [regex] type does NOT populate the Powershell automatic variable $matches. This behaviour is DIFFERENT from the .Match() method
      # Write-PSFMessage -Level Debug -Message "Entries[$($CompoundID.CollectionID)][$($CompoundID.KeyID)] DependsUpon $($collectionID.ToString() + $hashElementStringSeperator) + $regexMatches['Earlier']"
      # ToDo: test/verify when the RHS references multiple $destination keys including individual, sequential, as operands, and recursive
      # ToDo: Recursivly expand the ValueToEvaluate looking for other optional dependencies
      # $parentCollectionID = $collections[$collectionID].ParentCompoundID.CollectionID
      # ToDo: instead of the pipeline below, simplify the expression that creates an array of values from the $regexMatches
      # $matchArray = $($regexMatches.Groups).Captures | ? { $_.Name -match 'Earlier' } | % { $_.Value } # nope, this doesn't work
      $matchArray = $($regexMatches.Groups).Captures | ? { $_.Name -match 'Earlier' } | % { $_.Value }

      # either create or append $dependsUpon
      if ($dependsUpon) {
        $dependsUpon['Destination'] = $matchArray
        # $dependsUpon += @(, @{CollectionID = $null ; MatchArray = $matchArray })
      }
      else {
        $dependsUpon = @{Destination = $matchArray }
        #$dependsUpon = @(, @{CollectionID = $null ; MatchArray = $matchArray })
      }
    }
    # Add DependsUpon key if needed
    if ($dependsUpon) { $($entries[$compoundID])['DependsUpon'] = $dependsUpon
    }
    Write-PSFMessage -Level Debug -Message "entry = $(Write-HashIndented $entries[$compoundID])"
  }

  # iterate over all the elements of a collection
  function WalkCollection {
    [CmdletBinding()]
    param (
      [Parameter()]
      [Guid]
      $collectionID
    )
    Write-PSFMessage -Level Debug -Message "collectionID = $collectionID "
    switch ($collections[$collectionID].Collection.gettype().fullname) {
      'System.Collections.Hashtable' {
        foreach ($keyID in $collections[$collectionID].Collection.Keys) {
          switch -regex ($collections[$collectionID].Collection[$KeyID].GetType().fullname) {
            ('System.Collections.Hashtable|System.Object\[\]') {
              $parentCompoundID = @{
                CollectionID = $CollectionID
                KeyID        = $keyID
              }
              $newCollectionID = New-Guid
              CreateSubordinateCollectionEntry -ParentCompoundID $parentCompoundID
              CreateCollection -CollectionID $newCollectionID -Collection $collections[$collectionID].Collection[$KeyID] -parentCompoundID $parentCompoundID
              WalkCollection -CollectionID $newCollectionID
            }
            'System.String' {
              CreateEntries -CollectionID $collectionID -KeyID $keyID
            }
            default {
              throw
            }
          }
        }
      }
      'System.Object[]' {
        for ($index = 0; $index -lt $collections[$collectionID].Collection.Count; $index++) {
          switch -regex ($collections[$collectionID].Collection[$index].GetType().fullname) {
            ('System.Collections.Hashtable|System.Object\[\]') {
              $parentCompoundID = @{
                CollectionID = $CollectionID
                KeyID        = $index
              }
              $newCollectionID = New-Guid
              CreateSubordinateCollectionEntry -ParentCompoundID $parentCompoundID
              CreateCollection -CollectionID $newCollectionID -Collection $collections[$collectionID].Collection[$index] -parentCompoundID $parentCompoundID
              WalkCollection -CollectionID $newCollectionID
            }
            ('System.String|System.Int32') {
              CreateEntries -CollectionID $collectionID -Index $index
            }
            default {
              throw
            }
          }
        }
      }
      default {
        throw
      }
    }

  }

  function WalkCollectionNew {
    [CmdletBinding()]
    param (
      [Parameter()]
      [Guid]
      $collectionID
    )
    Write-PSFMessage -Level Debug -Message "collectionID = $collectionID "
    switch ($collections[$collectionID].Collection.gettype().fullname) {
      'System.Collections.Hashtable' {
        foreach ($keyID in $collections[$collectionID].Collection.Keys) {
          switch -regex ($collections[$collectionID].Collection[$KeyID].GetType().fullname) {
            ('System.Collections.Hashtable|System.Object\[\]') {
              $parentCompoundID = [CompoundID]::new($CollectionID, $keyID)
              $newCollectionID = New-Guid
              CreateSubordinateCollectionEntry -ParentCompoundID $parentCompoundID
              CreateCollection -CollectionID $newCollectionID -Collection $collections[$collectionID].Collection[$KeyID] -parentCompoundID $parentCompoundID
              WalkCollection -CollectionID $newCollectionID
            }
            'System.String' {
              CreateEntries -CollectionID $collectionID -KeyID $keyID
            }
            default {
              throw
            }
          }
        }
      }
      'System.Object[]' {
        for ($index = 0; $index -lt $collections[$collectionID].Collection.Count; $index++) {
          switch -regex ($collections[$collectionID].Collection[$index].GetType().fullname) {
            ('System.Collections.Hashtable|System.Object\[\]') {
              $parentCompoundID = @{
                CollectionID = $CollectionID
                KeyID        = $index
              }
              $newCollectionID = New-Guid
              CreateSubordinateCollectionEntry -ParentCompoundID $parentCompoundID
              CreateCollection -CollectionID $newCollectionID -Collection $collections[$collectionID].Collection[$index] -parentCompoundID $parentCompoundID
              WalkCollection -CollectionID $newCollectionID
            }
            ('System.String|System.Int32') {
              CreateEntries -CollectionID $collectionID -Index $index
            }
            default {
              throw
            }
          }
        }
      }
      default {
        throw
      }
    }

  }

  function SortEntries {
    [CmdletBinding(DefaultParameterSetName = 'Hashtable')]
    param (
    )
    # Convert the $entries into a format suitable for the topological sort
    $keySB = New-Object System.Text.StringBuilder
    $earlierKeySB = New-Object System.Text.StringBuilder
    $earlierCollection = New-Object System.Collections.ArrayList
    $earlierCollections = New-Object System.Collections.ArrayList
    $flatDependsUpon = New-Object System.Collections.ArrayList

    function RecursivlyPrependParent {
      param (
        [Parameter()]
        [object] $compoundID
      )
      $null = $keySB.Insert(0, '}')
      $null = $keySB.Insert(0, $($collections[$compoundID.CollectionID].ParentCompoundID.KeyID))
      $null = $keySB.Insert(0, $hashElementStringSeperator)
      $null = $keySB.Insert(0, $($collections[$compoundID.CollectionID].ParentCompoundID.CollectionID).ToString())
      $null = $keySB.Insert(0, '{')
      if ($collections[$collections[$compoundID.CollectionID].ParentCompoundID.CollectionID].ContainsKey('ParentCompoundID')) {
        RecursivlyPrependParent $collections[$collections[$compoundID.CollectionID].ParentCompoundID.CollectionID].ParentCompoundID
      }
    }
    Write-PSFMessage -Level Debug -Message 'SortEntries'
    # Outermost loop goes around every key in $entries
    foreach ($compoundID in $entries.Keys) {
      if ($collections[$compoundID.CollectionID].ContainsKey('ParentCompoundID')) {
        # the $keystr that forms the key of the dependency entry has will have any and all parent compoundId's included as part of the key
        RecursivlyPrependParent $compoundID
      }
      # Convert the fields of the compoundID into a string representation
      $keystr = CompoundIDToString $compoundID

      if ($entries[$compoundID].ContainsKey('DependsUpon')) {
        # if it DependsUpon a destination key, it has an dependentUpon element with no collectionID and a MatchArray. The entry's ValueToEvaluate must be evaluated
        # if it DependsUpon a parent key, it has an dependentUpon element with the parent collectionID and the parent KeyID. The entry cannot be evaulated until the partent is created.
        # if the entry dependsUpon both, there will be two dependency entries.
        # if there are two dependency entries, the parent's entry's ValueToEvaluate must be evaluated done before this entry is evaluated
        if ($entries[$compoundID].DependsUpon.ContainsKey('Parent')) {
        }
        if ($entries[$compoundID].DependsUpon.ContainsKey('Destination')) {
          $earlierCollectionID = $entries[$compoundID].DependsUpon.Destination.CollectionID
          $earlierMatchArray = $entries[$compoundID].DependsUpon.Destination.MatchArray
        }
        foreach ( $dependentUpon in $entries[$compoundID].DependsUpon) {
          $earlierCollectionID = $dependentUpon.CollectionID
          $earlierMatchArray = $dependentUpon.MatchArray
          foreach ($element in $earlierMatchArray) {
            if ($earlierCollectionID -and $collections[$earlierCollectionID].ContainsKey('ParentCompoundID')) {
              $null = $earlierKeySB.Append($($collections[$element.CollectionID].ParentCompoundID.CollectionID).ToString())
            }
            $null = $earlierKeySB.Append($hashElementStringSeperator)
            $null = $earlierKeySB.Append($element)
            $null = $earlierCollection.Add($earlierKeySB.ToString())
            $null = $earlierKeySB.Clear()
          }
          $null = $earlierCollections.Add( [System.Collections.ArrayList]::new($earlierCollection))
          $null = $earlierCollection.Clear()
        }

        # flatten the collections
        foreach ($earlierCollection in $earlierCollections) {
          $null = $flatDependsUpon.Add($earlierCollection)
        }
        $dependencyHash[$keystr] = [array] $flatDependsUpon
        $null = $earlierCollections.Clear()
        $null = $flatDependsUpon.Clear()
      }
      else {
        # The entry's VauleToEvaluate should be assigned to the destination entry with no further evaluation
        $dependencyHash[$keystr] = @()
      }
    }

    # Log the $dependencyHash
    if ($debugpreference -eq 'Continue') {

      foreach ($key in $dependencyHash.keys) {
        $part2 = $null
        if ($dependencyHash[$key]) {
          for ($index = 0; $index -lt $dependencyHash[$key].Count; $index++) {
            $dependentUpon = $($dependencyHash[$key])[$index]
            $part2 += $dependentUpon + '   '
          }
        }
        $message = "DependencyHash $key = $part2"
        Write-PSFMessage -Level Debug -Message $message
      }
    }
    # return the results of the topological sort
    Get-TopologicalSort -EdgeList $dependencyHash
  }

  ### Starts here
  foreach ($collectionToEvaluate in $sourceCollections ) { #()) {
    $collectionID = New-Guid
    CreateCollection -CollectionID $collectionID -Collection $collectionToEvaluate
    WalkCollection -CollectionID $collectionID
  }
  # log the entries and their dependencies for debugging
  if ($debugpreference -eq 'Continue') {
    foreach ($key in $entries.keys) {
      $hasDependsUpon = $entries[$key].ContainsKey('DependsUpon') ? 'True' : 'false'
      $hasDependsUponCount = $null
      $dependsUponStr = [Environment]::NewLine
      if ($hasDependsUpon) {
        $hasDependsUponCount = $entries[$key].DependsUpon.count
      }
      if ($hasDependsUpon) {
        foreach ($dependsUponEntry in $entries[$key].DependsUpon) {
          if ($dependsUponEntry.CollectionID) {
            $dependsUponStr += $($dependsUponEntry.CollectionID.ToString() + ':::' + $dependsUponEntry.MatchArray )
          }
          else {
            $dependsUponStr += $(':::' + $dependsUponEntry.MatchArray )
          }
          $dependsUponStr += [Environment]::NewLine
        }
        $hasDependsUponCount = $entries[$key].DependsUpon.count
      }

      $message = "LogEntries: {$($key.CollectionID): $($key.KeyID)} = $($entries[$key].ValueToEvaluate.gettype()): $($entries[$key].ValueToEvaluate) ::: HasDependsUpon = $hasDependsUpon $hasDependsUponCount $dependsUponStr"
      Write-PSFMessage -Level Debug -Message $message
    }
  }
  # end logging
  # Sort the entries collection, creating a sortedEntries Arraylist structure
  $sortedEntryKeys = [System.Collections.ArrayList]::new($(SortEntries))

  # remove any destination only keys
  foreach ($srcEntryKey in $sortedEntryKeys.Where({ -not $_.StartsWith('{') })) {
    $sortedEntryKeys.Remove($srcEntryKey)
  }

  # Process the entries in the order of sortedEntryKeys and create the final $destination structure
  $subordinateCompoundIDs = New-Object System.Collections.ArrayList
  $topLevelCompoundIDs = New-Object System.Collections.ArrayList

  foreach ($compoundIDStr in $sortedEntryKeys) {
    $compoundID = CompoundIDFromString $compoundIDStr
    # create the destination key and value
    if ($collections[$compoundID.CollectionID].ContainsKey('ParentCompoundID')) {
      # the collection is not a toplevel collection
      $null = $subordinateCompoundIDs.Add($compoundID)
    }
    else {
      # the collection IS a toplevel collection
      $null = $topLevelCompoundIDs.Add($compoundID)
    }
  }

  foreach ($compoundID in $topLevelCompoundIDs) {
    Write-PSFMessage -Level Important -Message "{$($compoundID.CollectionID): $($compoundID.KeyID)} = $($entries[$compoundID].ValueToEvaluate.gettype()): $($entries[$compoundID].ValueToEvaluate)"
    # does the entry dependsUpon anything?
    if ($entries[$compoundID].ContainsKey('DependsUpon') -and $entries[$compoundID].ContainsKey('DependsUpon')) {
      # yes, the value to evaluate must be invoked
      Write-PSFMessage -Level Important -Message "{$($compoundID.CollectionID): $($compoundID.KeyID)} :: DependsUpon = $(Write-HashIndented $($($entries[$compoundID]).DependsUpon))"
      $destination[$compoundID.KeyID] = Invoke-Expression $entries[$compoundID].ValueToEvaluate
    }
    else {
      # otherwise the destination value is just the entry's value
      $destination[$compoundID.KeyID] = $entries[$compoundID].ValueToEvaluate
    }
  }

  foreach ($compoundID in $subordinateCompoundIDs) {
    Write-PSFMessage -Level Important -Message "{$($compoundID.CollectionID): $($compoundID.KeyID)} = $($entries[$compoundID].ValueToEvaluate.gettype()): $($entries[$compoundID].ValueToEvaluate) :: DependsUpon = $(Write-HashIndented $($($entries[$compoundID]).DependsUpon)))"
    #
  }
  # Process the settings for collections having no parent and entry that depends upon nothing
  # foreach ($collectionID in $($sortedIntermediateSettings.Collections).Keys) {
  #   if (-not $($($sortedIntermediateSettings.Collections)[$collectionID]).ParentCollectionID) {
  #     foreach ($keyID in $sortedIntermediateSettings.Collections[$collectionID].Collection.Keys) {
  #       Write-PSFMessage -Level Debug -Message "ProcessSortedIntermediateCollection keyID  = $keyID collectionID = $collectionID ParentCollectionID = $($($collections[$collectionID]).ParentCollectionID) "
  #       #$compoundID =
  #       $destination[$entries[$compoundID].KeyID] = $entries[$compoundID].ValueToEvaluate
  #     }
  #   }
  # }
  # $destination
}

