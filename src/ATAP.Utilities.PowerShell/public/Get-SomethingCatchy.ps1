# Using statements ust be the first non-comment line in a script




# Many settings are defined in terms of other settings. Settings' values must be evaulated in such an order that earlier settings are evaulated before dependent settings.
# settings that are defined in terms of other settings are discovered by analysis of the destination.


function Get-SomethingCatchy {
  [CmdletBinding(DefaultParameterSetName = 'Hashtables')]
  param (
    [Parameter(Mandatory = $true)]
    [object[]]
    $sourceCollections
    # ToDo: support arrays as well as hashtables
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
  $DebugPreference = 'Continue' # 'Continue' # 'SilentlyContinue'
  # ToDo: ensure these are part of the ATAP powershell package
  . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Powershell\public\Get-ClonedObject.ps1'
  . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Powershell\public\Get-TopologicalSort.ps1'

  # Declare function-scope variables visible to all functions
  $collections = @{}
  $entries = @{}
  [System.Collections.Hashtable] $CompoundIDLookup = @{}

  class CompoundID {
    [guid] $CollectionID
    # ToDo: only string and int are supported. No Validation yet.
    [object] $Key
    [int]$sortOrder
    # # Todo: make this thread-safe
    hidden static [System.Text.StringBuilder] $keySB
    hidden static [System.String] $stringSeperator = $hashElementStringSeperator
    # # Todo: make this thread-safe
    # [System.Collections.Hashtable] $CompoundIDLookup = @{} # todo make this hidden and static

    static CompoundID() {
      [CompoundID]::keySB = New-Object System.Text.StringBuilder
      # [CompoundID]::stringSeperator = $hashElementStringSeperator
    }

    CompoundID(
      [guid] $CollectionID
      , [object] $Key
      , [int] $SortOrder
    ) {
      # ToDo: Validate that $key is of a supported type
      $this.CollectionID = $CollectionID
      $this.Key = $Key
      $this.SortOrder = $SortOrder
      # $this.CompoundIDLookup[$this.ToString()] = $this # eventually make use of a hidden static hashtable built into the CompoundID clas
    }
    [string] ToString() {
      return $this.ToString([string][CompoundID]::stringSeperator)
    }
    # # Todo: make this thread-safe
    [string] ToString([string] $stringSeperator) {

      [void][CompoundID]::keySB.Clear()
      [void][CompoundID]::keySB.Append('{')
      [void][CompoundID]::keySB.Append($this.CollectionID)
      [void][CompoundID]::keySB.Append($stringSeperator)
      [void][CompoundID]::keySB.Append($this.Key)
      [void][CompoundID]::keySB.Append('}')
      return [CompoundID]::keySB.ToString()
    }
  }

  # [In Powershell, how do I sort a Collections.Generic.List of DirectoryInfo?](https://stackoverflow.com/questions/65960853/in-powershell-how-do-i-sort-a-collections-generic-list-of-directoryinfo)
  # [](https://www.youtube.com/watch?v=zggWL-0gefo)
  class CompoundIDComparer : System.Collections.Generic.IComparer[CompoundID] {
    [int]Compare([CompoundID]$a, [CompoundID]$b) {
      return $a.SortOrder.CompareTo($b.SortOrder)
    }
  }

  class EntryKey {
    [System.Collections.Generic.SortedSet[CompoundID]] $Set
    static hidden [System.Collections.Generic.IComparer[CompoundID]] $CompoundIDComparer = [CompoundIDComparer]::new()
    # # Todo: make this thread-safe
    hidden static [System.Text.StringBuilder] $keySB
    hidden static [System.Text.StringBuilder] $OffsetSB
    static [System.Collections.Hashtable] $Lookup

    static EntryKey( ) {
      [EntryKey]::CompoundIDComparer = [CompoundIDComparer]::new()
      [EntryKey]::keySB = New-Object System.Text.StringBuilder
      [EntryKey]::OffsetSB = New-Object System.Text.StringBuilder
      [EntryKey]::Lookup = @{}
    }
    EntryKey( ) {
      $this.Set = [System.Collections.Generic.SortedSet[CompoundID]]::new([System.Collections.Generic.IComparer[CompoundID]] [EntryKey]::CompoundIDComparer)
      [EntryKey]::Lookup[$this.ToString()] = $this
    }
    # ToDo: use constructor chaining when powershell supportsd it
    EntryKey([CompoundID] $CompoundID ) {
      # $this.EntryKey()
      $this.Set = [System.Collections.Generic.SortedSet[CompoundID]]::new([System.Collections.Generic.IComparer[CompoundID]] [EntryKey]::CompoundIDComparer)
      $this.Set.Add([CompoundID]$CompoundID)
      [EntryKey]::Lookup[$this.ToString()] = $this
    }
    # ToDo: use constructor chaining when powershell supportsd it
    EntryKey([System.Collections.Generic.SortedSet[CompoundID]] $ParentSet, [CompoundID] $CompoundID ) {
      #$this.EntryKey()
      $this.Set = [System.Collections.Generic.SortedSet[CompoundID]]::new([System.Collections.Generic.IComparer[CompoundID]] [EntryKey]::CompoundIDComparer)
      foreach ($ci in $ParentSet) {
        $this.Set.Add($ci)
      }
      # ToDo - wrap in a try/catch, and test for a hashset collision if the new compoundID already exists (?)
      # if the new compound ID
      $this.Set.Add([CompoundID]$CompoundID)
      [EntryKey]::Lookup[$this.ToString()] = $this
    }
    [CompoundID] Max() {
      return $this.Set.Max
    }
    [CompoundID] Min() {
      return $this.Set.Min
    }
    # # Todo: make this thread-safe
    [string] ToString() {
      foreach ($compoundID in $this.set) {
        [void][EntryKey]::keySB.Clear()
        [void][EntryKey]::keySB.Append('{')
        [void][EntryKey]::keySB.Append($compoundID.ToString())
        [void][EntryKey]::keySB.Append('}')
      }
      return [EntryKey]::keySB.ToString()
    }
    # ToDo: validate $base is addressable with a key or index
    # [object] ToOffset($base) {
    #   $offsetPtr = $base
    #   foreach ($compoundID in $this.Set ) {
    #     $offsetPtr = $offsetPtr[$compoundID.Key]
    #   }
    #   return $offsetPtr
    #   #    [void][EntryKey]::OffsetSB.Clear()
    #   #   # [void][EntryKey]::OffsetSB.Append('$destination[''')
    #   #   [void][EntryKey]::OffsetSB.Append($this.Min().Key)
    #   #   # [void][EntryKey]::OffsetSB.Append(''']')
    #   #   if ($this.Set.Count -gt 1) {
    #   #     # All members of the sorted set except for the first
    #   #     $EntryKeySubSet = $($this.Set)[1..$($($this.Set.Count) - 1)]
    #   #     foreach ($compoundID in $EntryKeySubSet ) {
    #   #       # [void][EntryKey]::OffsetSB.Insert(0, '$(')
    #   #       # [void][EntryKey]::OffsetSB.Append(')[''')
    #   #       # [void][EntryKey]::OffsetSB.Append($compoundID.Key)
    #   #       # [void][EntryKey]::OffsetSB.Append(''']')
    #   #       [void][EntryKey]::OffsetSB.Append('[''')
    #   #       [void][EntryKey]::OffsetSB.Append($compoundID.Key)
    #   #       [void][EntryKey]::OffsetSB.Append(''']')
    #   #     }
    #   #   }
    #   #   return [EntryKey]::OffsetSB.ToString()
    # }
    # ToDo: validate $base is addressable with a key or index
    [void]SetAtOffset($base, [object] $value) {
      $offsetPtr = $base
      if ($this.Set.Count -gt 1) {
      # All members of the sorted set except for the last
      for ($i = 0; $i -lt $($this.Set.Count - 1); $i++) {
        
        switch ($offsetPtr[$($this.Set)[$i].Key].gettype().fullname) {
          'System.Collections.Hashtable' {
            $offsetPtr = $offsetPtr[$($this.Set)[$i].Key]
           }
          'System.Object[]' { }# ToDo
          default {
            throw
          }
        }
      }
    }
    $offsetPtr[$this.Max().Key] = $value
  }
  }
  class EntryValue {
    [object] $ValueToEvaluate
    [EntryKey] $DependsUponParent
    [string] $DependsUponDestination
    hidden static [System.Text.StringBuilder] $keySB

    static EntryValue( ) {
      [EntryValue]::keySB = New-Object System.Text.StringBuilder
    }
    EntryValue([object]$valueToEvaluate ) {
      $this.ValueToEvaluate = $valueToEvaluate
      $this.DependsUponParent = $null
      $this.DependsUponDestination = $null
    }
    EntryValue([object]$valueToEvaluate, [EntryKey]$dependsUponParent) {
      $this.ValueToEvaluate = $valueToEvaluate
      $this.DependsUponParent = $dependsUponParent
      $this.DependsUponDestination = $null
    }
    EntryValue([object]$valueToEvaluate, [string]$dependsUponDestination) {
      $this.ValueToEvaluate = $valueToEvaluate
      $this.DependsUponParent = $null
      $this.DependsUponDestination = $dependsUponDestination
    }
    EntryValue([object]$valueToEvaluate, [EntryKey]$dependsUponParent, [string]$dependsUponDestination ) {
      $this.ValueToEvaluate = $valueToEvaluate
      $this.DependsUponParent = $dependsUponParent
      $this.DependsUponDestination = $dependsUponDestination
    }
    # # Todo: make this thread-safe
    [string] ToString() {

      [void][EntryValue]::keySB.Clear()
      [void][EntryValue]::keySB.Append('{')
      [void][EntryValue]::keySB.Append("ValueToEvalute = $($($this.ValueToEvaluate).ToString())")
      [void][EntryValue]::keySB.Append('  ')
      [void][EntryValue]::keySB.Append("DependsUponParent = $($this.DependsUponParent ? $($($this.DependsUponParent).ToString()) : '')")
      [void][EntryValue]::keySB.Append('  ')
      [void][EntryValue]::keySB.Append("DependsUponDestination = $($this.DependsUponDestination ? $($($this.DependsUponDestination).ToString()) : '')")
      [void][EntryValue]::keySB.Append('}')
      return [EntryValue]::keySB.ToString()
    }
  }

  # Create an entry that creates a subordinatecollection:
  function CreateSubordinateCollectionEntry {
    [CmdletBinding()]
    param (
      [Parameter()]
      [EntryKey]
      $parentEntryKey
    )
    switch ($collections[$parentEntryKey.Max().CollectionID].Collection[$parentEntryKey.Max().Key].GetType().fullname) {
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
    [EntryValue] $entryValue = [EntryValue]::new( $valueToEvaluate )
    if ($collections[$parentEntryKey.Max().collectionID].ContainsKey('ParentEntryKey')) {
      $entryValue.DependsUponParent = $collections[$parentEntryKey.max().collectionID].ParentEntryKey
    }
    $entries[$parentEntryKey] = $entryValue
    # The entry that creates the child collection depends upon the parent entry might depend upon
    # if ($($entries[$parentEntryKey])) {
    #   if ($($entries[$parentEntryKey])['DependsUpon']) {
    #     # The the parent collection has dependencies
    #     $($entries[$subordinateEntryKey])['DependsUpon'] = $($entries[$parentEntryKey])['DependsUpon']
    #   }
    # }

  }

  # Create an entry in the $collections hash
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
      [EntryKey]
      $parentEntryKey
    )

    switch ($PsCmdlet.ParameterSetName) {
      'NoParent' {
        # Called with no parentEntryKey indicates a top-level (root) source collection is being processed
        Write-PSFMessage -Level Debug -Message "NoParent collectionID = $collectionID "
        $collections[$collectionID] = @{
          Collection = $collection
        }
      }
      'HasParent' {
        # Called with a parentEntryKey indicates a subordinate source collection is being processed
        Write-PSFMessage -Level Debug -Message "HasParent collectionID = $collectionID : ParentCollectionID = $($parentEntryKey.max().CollectionID) : parentKey = $($parentEntryKey.max().Key)"
        $collections[$collectionID] = @{
          # Passing $null for parentEntryKey indicates a top-level Source hash is being processed
          ParentEntryKey = $parentEntryKey
          Collection     = $collection
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
      , [Parameter()]
      [int]
      $depth
      #, [Parameter(ParameterSetName = 'Hashtable')]
      , [Parameter()]
      [object]
      $keyID
      # , [Parameter(ParameterSetName = 'Array')]
      # [object]
      # $index
    )
    #
    $compoundID = [CompoundID]::new($collectionID, $keyID, $depth)
    $entryKey = $null
    if ($collections[$collectionID].ContainsKey('ParentEntryKey')) {
      # the entryKey for this entry is a completely new instance of an EntryKey type whose Set contains all elements of the parentEntryKey Set and adds the CompoundId instance of this collectionID and this keyID
      $entryKey = [EntryKey]::new([System.Collections.Generic.SortedSet[CompoundID]] $($collections[$collectionID].ParentEntryKey).Set, [CompoundID]$compoundID)
    }
    else {
      # the entryKey for this entry is a completely new instance of an EntryKey type whose Set contains just the CompoundId instance of this collectionID and this keyID
      $entryKey = [EntryKey]::new($compoundID)
    }
    # create an instance of the EntryValue type and assign it to this entry's $entries record
    [EntryValue] $entryValue = [EntryValue]::new( $collections[$collectionID].Collection[$keyID] )
    # Create this entry in the $entries hash
    $entries[$entryKey] = $entryValue

    # if the collection to which this entry belongs hase a parent collection, then this entry dependsUpon the parent, specifically the KeyID of the parent entryKey's max compoundID
    if ($collections[$collectionID].ContainsKey('ParentEntryKey')) {
      $entries[$entryKey].DependsUponParent = $collections[$collectionID].ParentEntryKey
    }

    # calculating the destination u->v dependencies. This entry is a vertice (V) node
    # does this value of this entry v reference another node u in the destination? (the match pattern provides one or more pattern-extracted substrings)
    # This algorithm only allows for values in a source collection to reference nodes in the destination collection
    # the destination collection ID is always $null
    $regexMatches = $matchPatternRegex.Matches($collections[$collectionID].Collection[$KeyID])
    if ($regexMatches.Success) {
      # the value of this entry depends on at least one other node u (a destination collection entry)
      #  the .Matches() method of a [regex] type does NOT populate the Powershell automatic variable $matches. This behaviour is DIFFERENT from the .Match() method
      # Write-PSFMessage -Level Debug -Message "Entries[$($CompoundID.CollectionID)][$($CompoundID.KeyID)] DependsUpon $($collectionID.ToString() + $hashElementStringSeperator) + $regexMatches['Earlier']"
      # ToDo: test/verify when the RHS references multiple $destination keys including individual, sequential, as operands, and recursive
      # ToDo: Recursivly expand the ValueToEvaluate looking for other optional dependencies
      # ToDo: instead of the pipeline below, simplify the expression that creates an array of values from the $regexMatches
      # $matchArray = $($regexMatches.Groups).Captures | ? { $_.Name -match 'Earlier' } | % { $_.Value } # nope, this doesn't work
      $matchArray = $($regexMatches.Groups).Captures | ? { $_.Name -match 'Earlier' } | % { $_.Value }
      $entries[$entryKey].DependsUponDestination = $matchArray
    }
    Write-PSFMessage -Level Debug -Message "entry = $($entries[$entryKey].ToString())"
  }

  # iterate over all the elements of a collection
  function WalkCollection {
    [CmdletBinding()]
    param (
      [Parameter()]
      [Guid]
      $collectionID
      , [Parameter()]
      [int]
      $depth
      , [Parameter()]
      [EntryKey]
      $parentEntryKey

    )
    Write-PSFMessage -Level Debug -Message "collectionID = $collectionID "
    switch ($collections[$collectionID].Collection.gettype().fullname) {
      'System.Collections.Hashtable' {
        foreach ($keyID in $collections[$collectionID].Collection.Keys) {
          switch -regex ($collections[$collectionID].Collection[$KeyID].GetType().fullname) {
            ('System.Collections.Hashtable|System.Object\[\]') {
              $parentCompoundID = [CompoundID]::new($CollectionID, $KeyID, $depth)
              $CompoundIDLookup[$parentCompoundID.ToString()] = $parentCompoundID
              $parentEntryKey = [EntryKey]::new($parentCompoundID)
              # entrykeylookup (?)
              CreateSubordinateCollectionEntry -ParentEntryKey $parentEntryKey
              $subordinateCollectionID = New-Guid
              CreateCollection -CollectionID $subordinateCollectionID -Collection $collections[$collectionID].Collection[$KeyID] -parentEntryKey $parentEntryKey
              $depth += 1
              WalkCollection -CollectionID $subordinateCollectionID -Depth $depth -parentEntryKey $parentEntryKey
              $depth -= 1
            }
            'System.String|System.Int' {
              CreateEntries -CollectionID $collectionID -KeyID $keyID -Depth $depth
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
              $parentCompoundID = [CompoundID]::new($CollectionID, $index, $depth )
              $CompoundIDLookup[$parentCompoundID.ToString()] = $parentCompoundID
              $parentEntryKey = [EntryKey]::new($parentCompoundID)
              CreateSubordinateCollectionEntry -ParentEntryKey $parentEntryKey
              $newCollectionID = New-Guid
              CreateCollection -CollectionID $newCollectionID -Collection $collections[$collectionID].Collection[$index] -parentEntryKey $parentEntryKey
              $depth += 1
              WalkCollection -CollectionID $newCollectionID -Depth $depth -parentEntryKey $parentEntryKey
              $depth -= 1
            }
            ('System.String|System.Int') {
              CreateEntries -CollectionID $collectionID -KeyID $index -Depth $depth
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
    $dependencyHash = @{}
    $flatDependsUpon = New-Object System.Collections.ArrayList

    Write-PSFMessage -Level Debug -Message 'SortEntries'
    # Outermost loop goes around every key in $entries
    foreach ($entryKey in $entries.Keys) {
      # Convert the fields of the entryKey into a string representation
      $keystr = $entryKey.ToString()
      if ($($entries[$entryKey]).DependsUponParent) {
        # if it DependsUpon a parent key, the entry cannot be evaluated until the parent is created.
        # The corresponding $dependencyHash's value for this $keystr must include the full parentEntryKey (as a string)
        [void]$flatDependsUpon.Add($($entries[$entryKey]).DependsUponParent.ToString())
      }
      if ($($entries[$entryKey]).DependsUponDestination) {
        # if it DependsUpon one or more destination keys, the entry cannot be evaluated until all of the referenced destination entries has been created.
        foreach ($element in $($entries[$entryKey]).DependsUponDestination.MatchArray) {
          [void]$flatDependsUpon.Add($element)
        }
      }
      $dependencyHash[$keystr] = [array] $flatDependsUpon
      [void]$flatDependsUpon.Clear()

    }

    # Log the $dependencyHash
    # if ($debugpreference -eq 'Continue') {

    #   foreach ($key in $dependencyHash.keys) {
    #     $part2 = $null
    #     if ($dependencyHash[$key]) {
    #       for ($index = 0; $index -lt $dependencyHash[$key].Count; $index++) {
    #         $dependentUpon = $($dependencyHash[$key])[$index]
    #         $part2 += $dependentUpon + '   '
    #       }
    #     }
    #     $message = "DependencyHash $key = $part2"
    #     Write-PSFMessage -Level Debug -Message $message
    #   }
    # }

    # sort the dependencyhash (all string based)
    $sortedEntryKeysStrings = Get-TopologicalSort -EdgeList $dependencyHash

    # convert the sortedEntryKeyStrings to a topologically sorted arry of Entrykey objects
    $sortedEntryKeys = [System.Collections.ArrayList]::new();
    foreach ($EntryKeysString in $sortedEntryKeysStrings) {
      [void]$sortedEntryKeys.Add([EntryKey]::Lookup[$EntryKeysString])
    }

    # upon return, Powershell will flatten an array of 1 element unless special syntax is used
    return @(, $sortedEntryKeys)
  }

  # format the entries and their dependencies into a hyuman-readable structure
  function Write-EntriesAndDependencies {
    param(
      [Parameter()]
      [Hashtable]
      $entries
    )
    foreach ($key in $entries.keys) {
      $message = "Entry at $($key.ToString()): Type is $($($entries[$key].ValueToEvaluate).gettype())::: `
      ValueToEvaluate is $($entries[$key].ValueToEvaluate) ::: dependsUponParent = $($entries[$key].DependsUponParent) `
       ::: dependsUponDestination = $($entries[$key].DependsUponDestination)"
      Write-PSFMessage -Level Debug -Message $message
    }

  }


  ### Starts here ######################################################################
  $depth = 0
  foreach ($collectionToEvaluate in $sourceCollections ) {
    #  handle edge case if called with empty collection
    if ($collectionToEvaluate.count -eq 0) { continue }
    $collectionID = New-Guid
    CreateCollection -CollectionID $collectionID -Collection $collectionToEvaluate
    WalkCollection -CollectionID $collectionID -Depth $depth
  }
  # logging
  if ($debugpreference -eq 'Continue') {
    Write-EntriesAndDependencies $entries
  }
  #  handle edge case if called with no entries in any collection
  if ($entries.count -eq 0) { return $destination }

  # Sort the entries collection, creating a sortedEntryKeys Arraylist structure
  $sortedEntryKeys = [System.Collections.ArrayList]::new($(SortEntries))

  # remove any destination only keys
  # foreach ($srcEntryKey in $sortedEntryKeys.Where({ -not $_.StartsWith('{') })) {
  #   $sortedEntryKeys.Remove($srcEntryKey)
  # }

  # Process the entries in the order of sortedEntryKeys and create the final $destination structure
  Write-PSFMessage -Level Debug -Message 'ProcessEntries'

  foreach ($EntryKey in $sortedEntryKeys) {
    #$destinationExpression = $EntryKey.ToOffset()
    #$ptr = $EntryKey.ToOffset($destination)
    $ValueToEvaluate = $entries[$EntryKey].ValueToEvaluate
    $valueType = $entries[$EntryKey].ValueToEvaluate.gettype().fullname
    Write-PSFMessage -Level Debug -Message "EntryKey = $($EntryKey.ToString()) ::  destinationExpression = $destinationExpression :: valueType  = $valueType  :: ValueToEvaluate = $($entries[$EntryKey].ValueToEvaluate)"
    switch -regex ($valueType) {
      ('System.Collections.Hashtable') {
        $EntryKey.SetAtOffset($destination, [System.Collections.Hashtable]::new())
        # $ptr = [System.Collections.Hashtable]::new()
        # $destination.Set_Item($destinationExpression,[System.Collections.Hashtable]::new())
        #$ValueToEvaluate = '[System.Collections.Hashtable]::new()'
      }
      ('System.Object\[\]') {
        $EntryKey.SetAtOffset($destination, [System.Object[]]::new())
        # $ptr = [System.Object[]]::new()
        # $destination.Set_Item($destinationExpression,[System.Object[]]::new())
        #$ValueToEvaluate = '[System.Object[]]::new()'
      }
      'System.String' {
        # if the entry's vaule depends on an entry in the destination, it must be evaluated before assignment
        if ($entries[$EntryKey].DependsUponDestination) {
          $evaluatedValue = $null
          # use the call operator and not invoke-expression, so as not to introduce an additional scope
          try {
            # [Try not catching Invoke-Expression error](https://social.technet.microsoft.com/Forums/en-US/9bcce59f-b51d-4745-a946-6323a0a57a15/try-not-catching-invokeexpression-error?forum=winserverpowershell)
            # [invoke-expression doesnot throw an error in powershell](https://stackoverflow.com/questions/31086630/invoke-expression-doesnot-throw-an-error-in-powershell)
            $er = ($evaluatedValue = & $ValueToEvaluate ) 2>&1
            if ($lastexitcode) { throw $er }
          }
          catch {
            # Wrap the string if it failed to evaluate
            # todo: what to do if it throws?
          }
          # $destination.Set_Item($destinationExpression, $evaluatedValue)
          $EntryKey.SetAtOffset($destination, $evaluatedValue)
          # $ptr = $evaluatedValue
          #$ValueToEvaluate = $evaluatedValue
        }
        else {
          $EntryKey.SetAtOffset($destination, $ValueToEvaluate)
          # $ptr = $evaluatedValue
          # $destination.Set_Item($destinationExpression, $ValueToEvaluate)
        }
        # else it needs no further processing
        # strings are evaluated twice, in order to execute any Powershell scriptblocks, functions,  or cmdlets
        # $evaluatedOnce = Invoke-Expression $ValueToEvaluate
        # $castToString = "'" +  $evaluatedOnce + "'"
        # $ValueToEvaluate = $castToString
      }
      'System.Int' {
        # numeric types need no special processing
        $EntryKey.SetAtOffset($destination, $ValueToEvaluate)
        # $ptr = $ValueToEvaluate
        # $destination.Set_Item($destinationExpression, $ValueToEvaluate)
      }
      default {
        throw
      }
    }
    # use the call operator and not invoke-expression, so as not to introduce an additional scope
    # & "$destinationExpression = $ValueToEvaluate"
  }

  #$destination
}

