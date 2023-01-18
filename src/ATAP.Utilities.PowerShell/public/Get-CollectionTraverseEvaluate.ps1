
# Many settings are defined in terms of other settings. Settings' values must be evaulated in such an order that earlier settings are evaulated before dependent settings.
# settings that are defined in terms of other settings are discovered by analysis of the destination.

function Get-CollectionTraverseEvaluate {
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
  # Allow the DebugPreference to be set for this function and it's children
  $DebugPreference = 'Continue' # 'Continue' # 'SilentlyContinue'

  # Declare classes used in this function
  class CompoundID {
    [Nullable[Guid]] $CollectionID
    [object] $Key # ToDo: Validate that $key is either an int or a string
    # These CompoundId instances are always used in a ordered Hashset, thus they include a SortOrder field
    [int] $sortOrder
    hidden static [System.Text.StringBuilder] $keySB # Todo: make these thread-safe
    static [System.Collections.Hashtable] $Lookup
    hidden static [System.String] $stringSeperator = $hashElementStringSeperator
    # FYI static constructors are always called first
    static CompoundID() {
      [CompoundID]::keySB = New-Object System.Text.StringBuilder
      [CompoundID]::Lookup = @{}

    }
    # No parameterless constructor. Some serialization libraries require a parameterless constructor.
    # ToDo: possible enhancement: Some serialization libraries require a parameterless constructor. if we need to serialize, add a parameterless constructor
    # ToDO: enhancement: make the CompoundID a generic based on the type of the ID (Guid, string, int)
    CompoundID(
      [Nullable[Guid]] $CollectionID
      , [object] $Key # ToDo: Validate that $key is either an int or a string
      , [int] $SortOrder
    ) {
      $this.CollectionID = $CollectionID
      $this.Key = $Key
      $this.SortOrder = $SortOrder
      [CompoundID]::Lookup[$this.ToString()] = $this
    }
    [string] ToString() {
      return $this.ToString([string][CompoundID]::stringSeperator)
    }
    [string] ToString([string] $stringSeperator) { # Todo: make this thread-safe
      [void][CompoundID]::keySB.Clear()
      [void][CompoundID]::keySB.Append('{')
      [void][CompoundID]::keySB.Append($this.CollectionID)
      [void][CompoundID]::keySB.Append($stringSeperator)
      [void][CompoundID]::keySB.Append($this.Key)
      [void][CompoundID]::keySB.Append('}')
      return [CompoundID]::keySB.ToString()
    }
  }
  #####################################################################
  # an IComparer function for CompoundID based on the SortOrder property
  # [In Powershell, how do I sort a Collections.Generic.List of DirectoryInfo?](https://stackoverflow.com/questions/65960853/in-powershell-how-do-i-sort-a-collections-generic-list-of-directoryinfo)
  # [](https://www.youtube.com/watch?v=zggWL-0gefo)
  class CompoundIDComparer : System.Collections.Generic.IComparer[CompoundID] {
    [int]Compare([CompoundID]$a, [CompoundID]$b) {
      return $a.SortOrder.CompareTo($b.SortOrder)
    }
  }

  #####################################################################
  # ToDO: enhancement: make the Collection a generic based on the type of the ID (Guid, string, int)
  class Collection {
    [Guid] $ID
    [object] $Collection # ToDo: specify that $Collection implements IEnumerable. [IEnumerable<object>] does not work
    [EntryKey] $ParentEntryKey # ToDo [Nullable[EntryKey]] will not work
    static [System.Collections.Hashtable] $Lookup
    static Collection() {
      [Collection]::Lookup = @{}
    }
    # No parameterless constructor. Some serialization libraries require a parameterless constructor.
    # ToDo: possible enhancement: Some serialization libraries require a parameterless constructor. if we need to serialize, add a parameterless constructor
    # ToDO: way future enhancement: make the ID and ParentID a generic based on the type of the ID (Guid, string, int)
    Collection(
      [Guid] $ID
      , [object] $Collection # ToDo: validate that the index into the IEnuerable is either a string or an int
    ) {
      $this.ID = $ID
      $this.Collection = $Collection
    }
    Collection(
      [Guid] $ID
      , [object] $Collection # ToDo: validate that the index into the IEnuerable is either a string or an int
      , [EntryKey] $ParentEntryKey
    ) {
      $this.ID = $ID
      $this.Collection = $Collection
      $this.ParentEntryKey = $ParentEntryKey
    }
  }

  #####################################################################
  # These objects form the key to the $entries structure. The Set property is the critical structure that makes the EntryKey comparable and uniquely hashable
  # EntryKey must  be serializable to be used with Get-ClonedObject
  class EntryKey {
    [System.Collections.Generic.SortedSet[CompoundID]] $Set
    static hidden [System.Collections.Generic.IComparer[CompoundID]] $CompoundIDComparer
    # # Todo: make these thread-safe
    hidden static [System.Text.StringBuilder] $keySB
    hidden static [System.Text.StringBuilder] $destinationKeyStringSB
    hidden static [System.Text.StringBuilder] $OffsetSB
    static [System.Collections.Hashtable] $Lookup

    static EntryKey( ) {
      [EntryKey]::CompoundIDComparer = [CompoundIDComparer]::new()
      [EntryKey]::keySB = New-Object System.Text.StringBuilder
      [EntryKey]::destinationKeyStringSB = New-Object System.Text.StringBuilder
      [EntryKey]::OffsetSB = New-Object System.Text.StringBuilder
      [EntryKey]::Lookup = @{}
    }

    # Parameterless constructor is required for serializing an object
    EntryKey() {
      $this.Set = [System.Collections.Generic.SortedSet[CompoundID]]::new([System.Collections.Generic.IComparer[CompoundID]] [EntryKey]::CompoundIDComparer)
    }

    # ToDo: use constructor chaining when powershell supports it
    EntryKey([CompoundID] $CompoundID ) {
      $this.Set = [System.Collections.Generic.SortedSet[CompoundID]]::new([System.Collections.Generic.IComparer[CompoundID]] [EntryKey]::CompoundIDComparer)
      $this.Set.Add([CompoundID]$CompoundID)
      # This constructor is used if there is no ParentEntryKey
      [EntryKey]::Lookup[$compoundID.Key] = $this
    }

    EntryKey([System.Collections.Generic.SortedSet[CompoundID]] $ParentSet, [CompoundID] $CompoundID ) {
      $this.Set = [System.Collections.Generic.SortedSet[CompoundID]]::new([System.Collections.Generic.IComparer[CompoundID]] [EntryKey]::CompoundIDComparer)
      foreach ($childCompoundID in $ParentSet) {
        try {
          $this.Set.Add($childCompoundID)
        }
        catch {
          $message = "Error adding the parent's Set's CompoundIDs to this Set, specifically: $($childCompoundID.ToString())"
          Write-PSFMessage -Level Error -Message $message
          throw $message
        }
      }
      # catch a hashset collision if the new compoundID already exists
      try {
        $this.Set.Add([CompoundID]$CompoundID)
      }
      catch {
        $message = "Attempt to add a duplicate CompoundID to this Set: $($CompoundID.ToString())"
        Write-PSFMessage -Level Error -Message $message
        throw $message
      }
      # crossreference structure for the string representation to the actual instance pointer
      [EntryKey]::Lookup[$($CompoundID.Key + $this.ToString())] = $this
    }

    [CompoundID] Max() { # Todo: make this thread-safe
      return $this.Set.Max
    }

    [CompoundID] Min() { # Todo: make this thread-safe
      return $this.Set.Min
    }

    [string] ToString() { # Todo: make this thread-safe
      [void][EntryKey]::keySB.Clear()
      foreach ($compoundID in $this.set) {
        [void][EntryKey]::keySB.Append('{')
        [void][EntryKey]::keySB.Append($compoundID.ToString())
        [void][EntryKey]::keySB.Append('}')
      }
      return [EntryKey]::keySB.ToString()
    }

    [string] ToDestinationKeyString() {
      [void][EntryKey]::DestinationKeyStringSB.Clear()
      [void][EntryKey]::DestinationKeyStringSB.Append($this.Min().Key)
      if ($this.Set.Count -gt 1) {
        # All members of the sorted set except for the first
        for ($i = 1; $i -lt $($this.Set.Count); $i++) {
          [void][EntryKey]::DestinationKeyStringSB.Append('{')
          [void][EntryKey]::DestinationKeyStringSB.Append($($($this.Set)[$i]).ToString())
          [void][EntryKey]::DestinationKeyStringSB.Append('}')
        }
      }
      return [EntryKey]::DestinationKeyStringSB.ToString()
    }

    [object] ToOffsetStr($base) { # ToDo: validate $base is addressable with a key or index
      [void][EntryKey]::OffsetSB.Clear()
      [void][EntryKey]::OffsetSB.Append($this.Min().Key)
      if ($this.Set.Count -gt 1) {
        # All members of the sorted set except for the first
        $EntryKeySubSet = $($this.Set)[1..$($($this.Set.Count) - 1)]
        foreach ($compoundID in $EntryKeySubSet ) {
          [void][EntryKey]::OffsetSB.Append('[''')
          [void][EntryKey]::OffsetSB.Append($compoundID.Key)
          [void][EntryKey]::OffsetSB.Append(''']')
        }
      }
      return [EntryKey]::OffsetSB.ToString()
    }

    [void] SetAtOffset($base, [object] $value) { # ToDo: validate $base is addressable with a key or index
      $offsetPtr = $base
      if ($this.Set.Count -gt 1) {
        # All members of the sorted set except for the last
        # If there is more than one, then the offsetptr has to move through each CompoundID so it points to the instance of the subordinate collection
        for ($i = 0; $i -lt $($this.Set.Count - 1); $i++) {
          switch ($offsetPtr[$($this.Set)[$i].Key].gettype().fullname) {
            'System.Collections.Hashtable' {
              # Move the offset pointer to the next collection
              $offsetPtr = $offsetPtr[$($this.Set)[$i].Key]
            }
            # ToDo Deal with Arrays
            'System.Object[]' {
              # Move the offset pointer to the next collection
              # ToDO deal with arrays, test and debug
              $offsetPtr = $offsetPtr[$($this.Set)[$i][$($this.Set)[$i].Key]]
            }
            default {
              throw
            }
          }
        }
      }
      # Set the value at the last's collection's key
      $offsetPtr[$this.Max().Key] = $value
    }
  }
  #####################################################################
  #####################################################################
  class EntryValue {
    [string] $DestinationBaseKey
    [object] $ValueToEvaluate
    [EntryKey] $DependsUponParent
    [string] $DependsUponDestination
    hidden static [System.Text.StringBuilder] $keySB
    # hidden static [string] $substitutionRegexPattern = '(?<CRK>\$global:configRootKeys\[.*?\])'
    # hidden static [regex] $substitutionRegex = [System.Text.RegularExpressions.Regex]::new(([EntryValue]::$substitutionRegexPattern), [System.Text.RegularExpressions.RegexOptions]::Singleline + [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

    static EntryValue( ) {
      [EntryValue]::keySB = New-Object System.Text.StringBuilder
      #[EntryValue]::$substitutionRegexPattern = '\$global:configRootKeys\['
      #[EntryValue]::$substitutionRegex = [System.Text.RegularExpressions.Regex]::new(([EntryValue]::$substitutionRegexPattern), [System.Text.RegularExpressions.RegexOptions]::Singleline + [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    }

    [string] Substitute([string] $inputStr) {
      $substitutionRegexPattern = '(?<CRK>\$global:configRootKeys\[.*?\])'
      $substitutionRegex = [System.Text.RegularExpressions.Regex]::new(($substitutionRegexPattern), [System.Text.RegularExpressions.RegexOptions]::Singleline + [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
      $regexMatches = $substitutionRegex.Matches($inputStr)
      if ($regexMatches.Success) {
        $newStr = $inputStr
        $matchArray = @(, $($($regexMatches.Groups).Captures | Where-Object { $_.Name -match 'CRK' }) | ForEach-Object { $_.Value })
        for ($mAIndex = 0; $mAIndex -lt $matchArray.count; $mAIndex++) {
          # need a pair of ' characters around the string to use it as a key into the $destination hash
          $newStr = $newStr -replace [regex]::Escape($matchArray[$mAIndex]), $("'{0}'" -f $(Invoke-Expression $matchArray[$mAIndex]))
        }
        return $newStr
      }
      else {
        return $inputstr
      }
    }

    EntryValue([string] $destinationBaseKey, [object]$valueToEvaluate ) {
      $this.DestinationBaseKey = $destinationBaseKey
      $this.DependsUponParent = $null
      $this.DependsUponDestination = $null
      $this.ValueToEvaluate = $this.Substitute($valueToEvaluate)
    }
    EntryValue([string] $destinationBaseKey, [object]$valueToEvaluate, [EntryKey]$dependsUponParent) {
      $this.DestinationBaseKey = $destinationBaseKey
      $this.DependsUponParent = $dependsUponParent
      $this.DependsUponDestination = $null
      $this.ValueToEvaluate = $this.Substitute($valueToEvaluate)
    }
    EntryValue([string] $destinationBaseKey, [object]$valueToEvaluate, [string]$dependsUponDestination) {
      $this.DestinationBaseKey = $destinationBaseKey
      $this.DependsUponParent = $null
      $this.DependsUponDestination = $dependsUponDestination
      $this.ValueToEvaluate = $this.Substitute($valueToEvaluate)
    }
    EntryValue([string] $destinationBaseKey, [object]$valueToEvaluate, [EntryKey]$dependsUponParent, [string]$dependsUponDestination ) {
      $this.DestinationBaseKey = $destinationBaseKey
      $this.DependsUponParent = $dependsUponParent
      $this.DependsUponDestination = $dependsUponDestination
      $this.ValueToEvaluate = $this.Substitute($valueToEvaluate)
    }

    [string] ToString() { # Todo: make this thread-safe
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

  # ToDo: ensure these are part of the ATAP powershell package
  #. join-path -path $([Environment]::GetFolderPath('MyDocuments')) -ChildPath 'GitHub' -AdditionalChildPath @('ATAP.Utilities','src','ATAP.Utilities.PowerShell', 'public','Get-ClonedObject.ps1')
  #. join-path -path $([Environment]::GetFolderPath('MyDocuments')) -ChildPath 'GitHub' -AdditionalChildPath @('ATAP.Utilities','src','ATAP.Utilities.PowerShell', 'public','Get-TopologicalSort.ps1')
  . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Powershell\public\Get-ClonedObject.ps1'
  . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Powershell\public\Get-TopologicalSort.ps1'

  if ($DebugPreference -eq 'Continue') {
    . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Powershell\public\SomethingDebugUtilities.ps1'
  }

  # Declare function-scope variables visible to all child functions
  $collections = @{}
  $entries = @{}

  # Create an entry that creates a subordinatecollection
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
    [EntryValue] $entryValue = [EntryValue]::new($parentEntryKey.Max().Key, $valueToEvaluate )

    # Value of this entry must dependUpon the parent, and grandparents, if present
    # This is the first place that a parent comes into being for a new subordinate collection
    # ToDo: simplify by introducing a class and properties for collections
    if ($collections[$parentEntryKey.Max().collectionID].ParentEntryKey) {
      $entryValue.DependsUponParent = $collections[$parentEntryKey.max().collectionID].ParentEntryKey
    }
    # Write an entry corresponding to the location of the parent (collection:Key) instead of calling createentries
    # When this entry is later evaluated, it creates an empty collection of the appropriate kind
    $entries[$parentEntryKey] = $entryValue
  }

  # Create an entry in the $collections hash
  function CreateCollection {
    [CmdletBinding(DefaultParameterSetName = 'NoParent')]
    param (
      [Parameter()]
      [guid]
      $ID
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
        Write-PSFMessage -Level Debug -Message "NoParent collectionID = $ID "
        # $collections[$ID] = @{
        #   Collection = $collection
        # }
        $collections[$ID] = [Collection]::new($ID, $collection)
      }
      'HasParent' {
        # Called with a parentEntryKey indicates a subordinate source collection is being processed
        Write-PSFMessage -Level Debug -Message "HasParent collectionID = $ID : parentEntryKey = $($parentEntryKey.ToString())"
        $collections[$ID] = [Collection]::new($ID, $collection, $parentEntryKey)
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
    if ($collections[$collectionID].ParentEntryKey) {
      # the entryKey for this entry is a completely new instance of an EntryKey type whose Set contains all elements of the parentEntryKey Set and adds the CompoundId instance of this collectionID and this keyID
      $entryKey = [EntryKey]::new([System.Collections.Generic.SortedSet[CompoundID]] $($collections[$collectionID].ParentEntryKey).Set, [CompoundID]$compoundID)
    }
    else {
      # the entryKey for this entry is a completely new instance of an EntryKey type whose Set contains just the CompoundId instance of this collectionID and this keyID
      $entryKey = [EntryKey]::new($compoundID)
    }
    # create an instance of the EntryValue type and assign it to this entry's $entries record
    [EntryValue] $entryValue = [EntryValue]::new( $compoundID.Key, $collections[$collectionID].Collection[$keyID] )
    # Create this entry in the $entries hash
    $entries[$entryKey] = $entryValue

    # if the collection to which this entry belongs has a parent collection, then this entry dependsUpon the parent, specifically the KeyID of the parent entryKey's max compoundID
    if ($collections[$collectionID].ParentEntryKey) {
      $entries[$entryKey].DependsUponParent = $collections[$collectionID].ParentEntryKey
    }

    # calculating the destination u->v dependencies. This entry is a vertice (V) node
    # does this value of this entry v reference another node u in the destination? (the match pattern provides one or more pattern-extracted substrings)
    # This algorithm only allows for values in a source collection to reference nodes in the destination collection
    $regexMatches = $matchPatternRegex.Matches($entryValue.ValueToEvaluate)
    if ($regexMatches.Success) {
      # the value of this entry depends on at least one other node u (a destination collection entry)
      #  the .Matches() method of a [regex] type does NOT populate the Powershell automatic variable $matches. This behaviour is DIFFERENT from the .Match() method
      # Write-PSFMessage -Level Debug -Message "Entries[$($CompoundID.CollectionID)][$($CompoundID.KeyID)] DependsUpon $($collectionID.ToString() + $hashElementStringSeperator) + $regexMatches['Earlier']"
      # ToDo: test/verify when the RHS references multiple $destination keys including individual, sequential, as operands, and recursive
      # ToDo: Recursivly expand the ValueToEvaluate looking for other optional dependencies
      # ToDo: instead of the pipeline below, simplify the expression that creates an array of values from the $regexMatches
      # $matchArray = $($regexMatches.Groups).Captures | ? { $_.Name -match 'Earlier' } | % { $_.Value } # nope, this doesn't work
      $matchArray = @(, $($($regexMatches.Groups).Captures | Where-Object { $_.Name -match 'Earlier' }) | ForEach-Object { $_.Value })
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
      $ID
      , [Parameter()]
      [int]
      $depth
      , [Parameter()]
      [EntryKey]
      $parentEntryKey
    )
    Write-PSFMessage -Level Debug -Message "ID = $ID "
    switch ($collections[$ID].Collection.gettype().fullname) {
      'System.Collections.Hashtable' {
        foreach ($keyID in $collections[$ID].Collection.Keys) {
          switch -regex ($collections[$ID].Collection[$KeyID].GetType().fullname) {
            ('System.Collections.Hashtable|System.Object\[\]') {
              # The current collection and key become the parent of the new collection
              $parentCompoundID = [CompoundID]::new($ID, $KeyID, $depth)

              # if the current collection has a parent, the new parent entry key must include all of them, else this is an Entry Key with no parents
              if ($collections[$ID].ParentEntryKey) {
                $parentEntryKey = [EntryKey]::new($($collections[$ID]).ParentEntryKey , $parentCompoundID)
              }
              else {
                $parentEntryKey = [EntryKey]::new($parentCompoundID)
              }
              #  create the entrykey lookup for this new EntryKey
              [EntryKey]::Lookup[$parentEntryKey.ToString()] = $parentEntryKey
              CreateSubordinateCollectionEntry -ParentEntryKey $parentEntryKey
              $subordinateCollectionID = New-Guid
              CreateCollection -ID $subordinateCollectionID -Collection $collections[$ID].Collection[$KeyID] -parentEntryKey $parentEntryKey
              $depth += 1
              WalkCollection -ID $subordinateCollectionID -Depth $depth -parentEntryKey $parentEntryKey
              $depth -= 1
            }
            'System.String|System.Int' {
              CreateEntries -CollectionID $ID -KeyID $keyID -Depth $depth
            }
            default {
              throw
            }
          }
        }
      }
      'System.Object[]' {
        for ($index = 0; $index -lt $collections[$ID].Collection.Count; $index++) {
          switch -regex ($collections[$ID].Collection[$index].GetType().fullname) {
            ('System.Collections.Hashtable|System.Object\[\]') {
              $parentCompoundID = [CompoundID]::new($ID, $index, $depth )
              # if the current collection has a parent, the new parent entry key must include all of them, else this is an Entry Key with no parents
              if ($collections[$ID].ParentEntryKey) {
                $parentEntryKey = [EntryKey]::new($($collections[$ID]).ParentEntryKey , $parentCompoundID)
              }
              else {
                $parentEntryKey = [EntryKey]::new($parentCompoundID)
              }
              #  create the entrykey lookup for this new EntryKey
              [EntryKey]::Lookup[$parentEntryKey.ToString()] = $parentEntryKey
              CreateSubordinateCollectionEntry -ParentEntryKey $parentEntryKey
              $newCollectionID = New-Guid
              CreateCollection -ID $newCollectionID -Collection $collections[$ID].Collection[$index] -parentEntryKey $parentEntryKey
              $depth += 1
              WalkCollection -ID $newCollectionID -Depth $depth -parentEntryKey $parentEntryKey
              $depth -= 1
            }
            ('System.String|System.Int') {
              CreateEntries -CollectionID $ID -KeyID $index -Depth $depth
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
      # replace
      if ($($entries[$entryKey]).DependsUponParent) {
        # if it DependsUpon a parent key, the entry cannot be evaluated until the parent is created.
        # The corresponding $dependencyHash's value for this $entryKey must include the destination base keystring
        [void]$flatDependsUpon.Add($($entries[$entryKey]).DependsUponParent)
        # If the parent's set has a count of more than one, then the intermediate entries are each also part of the dependency hash
        if ($entries[$entryKey].Set.Count -gt 1) {
          # All members of the sorted set except for the first
          $EntryKeySubSet = $($this.Set)[1..$($($this.Set.Count) - 1)]
          foreach ($compoundID in $EntryKeySubSet ) {
            [void]$flatDependsUpon.Add($compoundID.ToString())
          }
        }
      }

      if ($($entries[$entryKey]).DependsUponDestination) {
        # if it DependsUpon one or more destination keys, the entry cannot be evaluated until all of the referenced destination entries has been created.
        foreach ($element in $($entries[$entryKey]).DependsUponDestination) {
          [void]$flatDependsUpon.Add($element)
        }
      }
      # Convert the fields of the entryKey into a string representation suitable for the topological sort
      $keystr = $entryKey.ToDestinationKeyString()
      $dependencyHash[$keystr] = [array] $flatDependsUpon
      [void]$flatDependsUpon.Clear()
    }

    # debugging
    if ($debugpreference -eq 'Continue') {
      Write-DependencyHash
    }

    # sort the dependencyhash (all string based)
    $sortedEntryKeysStrings = Get-TopologicalSort -EdgeList $dependencyHash

    # debugging
    if ($debugpreference -eq 'Continue') {
      write-NULLSortedEntryKeysString $sortedEntryKeysStrings
      Write-NullLookupKeys
      Write-DuplicateLookupKeys
    }

    # convert the sortedEntryKeyStrings to a topologically sorted array of EntryKey objects
    $EntryKeyStringWithNullValue = @()
    $sortedEntryKeys = [System.Collections.ArrayList]::new();
    foreach ($EntryKeysString in $sortedEntryKeysStrings) {
      [void]$sortedEntryKeys.Add([EntryKey]::Lookup[$EntryKeysString])
      if (-not [EntryKey]::Lookup[$EntryKeysString]) {
        $EntryKeyStringWithNullValue += $EntryKeysString
      }
    }
    Write-PSFMessage -Level Debug -Message "Number of NULL sortedEntryKeyFromLookup = $($EntryKeyStringWithNullValue.count):: List = $($EntryKeyStringWithNullValue -join ',')"
    # upon a return, Powershell will flatten an array of 1 element unless special syntax is used
    return @(, $sortedEntryKeys)
  }


  ### Starts here ######################################################################
  $depth = 0
  foreach ($collectionToEvaluate in $sourceCollections ) {
    #  handle edge case if called with empty collection
    if ($collectionToEvaluate.count -eq 0) { continue }
    $CollectionID = New-Guid
    CreateCollection -ID $CollectionID -Collection $collectionToEvaluate
    WalkCollection -ID $CollectionID -Depth $depth
  }

  # debugging
  if ($debugpreference -eq 'Continue') {
    Write-EntriesAndDependencies $entries
  }
  #  handle edge case if called with no entries in any collection
  if ($entries.count -eq 0) { return $destination }

  # Sort the entries collection, creating a sortedEntryKeys Arraylist structure
  $sortedEntryKeys = [System.Collections.ArrayList]::new($(SortEntries))

  # Process the entries in the order of sortedEntryKeys and create the final $destination structure
  Write-PSFMessage -Level Debug -Message 'ProcessEntries'

  # debugging
  if ($debugpreference -eq 'Continue') {
    Write-NULLSortedEntryKeys
  }

  # create the destination key->value pair
  foreach ($EntryKey in $sortedEntryKeys) {
    if ($debugpreference -eq 'Continue') {
      if (!$EntryKey) {
        Write-PSFMessage -Level Error -Message 'EntryKey IS NULL'
        # Should never be empty
        # ToDo: exception handling
        # temp: break out of the loop
        break
      }
    }
    Write-PSFMessage -Level Important -Message "EntryKey = $($EntryKey.ToString()) ::  destinationExpression = $destinationExpression :: valueType  = $valueType  :: ValueToEvaluate = $($entries[$EntryKey].ValueToEvaluate)"
    $ValueToEvaluate = $entries[$EntryKey].ValueToEvaluate
    $valueType = $entries[$EntryKey].ValueToEvaluate.gettype().fullname
    if ($debugpreference -eq 'Continue') {
      Write-PSFMessage -Level Debug -Message "EntryKey = $($EntryKey.ToString()) ::  destinationExpression = $destinationExpression :: valueType  = $valueType  :: ValueToEvaluate = $($entries[$EntryKey].ValueToEvaluate)"
    }
    switch -regex ($valueType) {
      ('System.Collections.Hashtable') {
        $EntryKey.SetAtOffset($destination, [System.Collections.Hashtable]::new())
      }
      ('System.Object\[\]') {
        $EntryKey.SetAtOffset($destination, [System.Object[]]::new($null))
      }
      'System.String' {
        # if the entry's vaule depends on an entry in the destination, it must be evaluated before assignment
        if ($entries[$EntryKey].DependsUponDestination) {
          $evaluatedValue = $null
          # use the call operator and not invoke-expression, so as not to introduce an additional scope
          try {
            # [Try not catching Invoke-Expression error](https://social.technet.microsoft.com/Forums/en-US/9bcce59f-b51d-4745-a946-6323a0a57a15/try-not-catching-invokeexpression-error?forum=winserverpowershell)
            # [invoke-expression does not throw an error in powershell](https://stackoverflow.com/questions/31086630/invoke-expression-doesnot-throw-an-error-in-powershell)
            # [PowerShell: Manage errors with Invoke-Expression](https://stackoverflow.com/questions/21583850/powershell-manage-errors-with-invoke-expression)
            $er = ($evaluatedValue = Invoke-Expression $ValueToEvaluate ) 2>&1
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
      }
      default {
        throw
      }
    }
    # use the call operator and not invoke-expression, so as not to introduce an additional scope
    # & "$destinationExpression = $ValueToEvaluate"
  }

  # clear the static lookup tables after the function ends
  [EntryKey]::Lookup = @{}
  #$destination
}

