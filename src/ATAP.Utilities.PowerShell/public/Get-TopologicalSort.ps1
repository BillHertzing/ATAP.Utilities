# Thanks to http://stackoverflow.com/questions/8982782/does-anyone-have-a-dependency-graph-and-topological-sorting-code-snippet-for-pow
# Input is a hashtable of @{ID = @(Depended,On,IDs);...}
function Get-TopologicalSort {
  [CmdletBinding()]
  param(
      [Parameter(Mandatory = $true, Position = 1)]
      [hashtable] $EdgeList
  )

  # Make sure we can use HashSet
  Add-Type -AssemblyName System.Core

  # Clone it so as to not alter original
          $currentEdgeList = [hashtable] (Get-ClonedObject $EdgeList)
  # algorithm from http://en.wikipedia.org/wiki/Topological_sorting#Algorithms
  $topologicallySortedElements = New-Object System.Collections.ArrayList
  $setOfAllNodesWithNoIncomingEdges = New-Object System.Collections.Queue

  $fasterEdgeList = @{}

  # Keep track of all nodes in case they put it in as an edge destination but not source
  $allNodesCollection = New-Object -TypeName System.Collections.Generic.HashSet[object] -ArgumentList (, [object[]] $currentEdgeList.Keys)

  foreach ($currentNode in $currentEdgeList.Keys) {
      $currentDestinationNodes = [array] $currentEdgeList[$currentNode]
      if ($currentDestinationNodes.Length -eq 0) {
          $setOfAllNodesWithNoIncomingEdges.Enqueue($currentNode)
      }

      foreach ($currentDestinationNode in $currentDestinationNodes) {
          if (!$allNodesCollection.Contains($currentDestinationNode)) {
              [void] $allNodesCollection.Add($currentDestinationNode)
          }
      }

      # Take this time to convert them to a HashSet for faster operation
      $currentDestinationNodes = New-Object -TypeName System.Collections.Generic.HashSet[object] -ArgumentList (, [object[]] $currentDestinationNodes )
      [void] $fasterEdgeList.Add($currentNode, $currentDestinationNodes)
  }

  # Now let's reconcile by adding empty dependencies for source nodes they didn't tell us about
  foreach ($currentNode in $allNodesCollection) {
      if (!$currentEdgeList.ContainsKey($currentNode)) {
          [void] $currentEdgeList.Add($currentNode, (New-Object -TypeName System.Collections.Generic.HashSet[object]))
          $setOfAllNodesWithNoIncomingEdges.Enqueue($currentNode)
      }
  }

  $currentEdgeList = $fasterEdgeList

  while ($setOfAllNodesWithNoIncomingEdges.Count -gt 0) {
      $currentNode = $setOfAllNodesWithNoIncomingEdges.Dequeue()
      [void] $currentEdgeList.Remove($currentNode)
      [void] $topologicallySortedElements.Add($currentNode)

      foreach ($currentEdgeSourceNode in $currentEdgeList.Keys) {
          $currentNodeDestinations = $currentEdgeList[$currentEdgeSourceNode]
          if ($currentNodeDestinations.Contains($currentNode)) {
              [void] $currentNodeDestinations.Remove($currentNode)

              if ($currentNodeDestinations.Count -eq 0) {
                  [void] $setOfAllNodesWithNoIncomingEdges.Enqueue($currentEdgeSourceNode)
              }
          }
      }
  }

  if ($currentEdgeList.Count -gt 0) {
      throw 'Graph has at least one cycle!'
  }
  $topologicallySortedElements
}
# write-host "Test1"
# $a = 'a';$b = 'b';$c = 'c';$d = 'd';$e = 'e';$src = @{$a = @(); $b= @($a); $c=@($a,$b); $d=@($a,$b); $e=@($a,$b,$c)};$src.keys | %{$_;$src[$_] -eq $_}
# write-host "Test2"
# $a = 'a';$b = 'b';$c = 'c';$d = 'd';$e = 'e';$src = @{$a = @(); $b= @($a); $c=@($a,$b); $d=@($a,$b); $e=@($a,$b,$c)};get-topologicalsort -stringEdgeList $src
# write-host "Test3"
# $a = @{keyID='a'};$b = @{keyID='b'};$c = @{keyID='c'};$d = @{keyID='d'};$e = @{keyID='e'};$src = @{$a = @(); $b= @($a); $c=@($a,$b); $d=@($a,$b); $e=@($a,$b,$c)};$src.keys | %{$_;$src[$_] -eq $_}
# write-host "Test4"
# $a = @{keyID='a'};$b = @{keyID='b'};$c = @{keyID='c'};$d = @{keyID='d'};$e = @{keyID='e'};$src = @{$a = @(); $b= @($a); $c=@($a,$b); $d=@($a,$b); $e=@($a,$b,$c)};get-topologicalsort -hashEdgeList $src
# write-host "Test5"
# $a = @{collectionID = '123'; keyID='a'};$b = @{collectionID = '123'; keyID='b'};$c = @{collectionID = '123'; keyID='c'};$d = @{collectionID = '123'; keyID='d'};$e = @{collectionID = '123'; keyID='e'};$src = @{$a = @(); $b= @($a); $c=@($a,$b); $d=@($a,$b); $e=@($a,$b,$c)};get-topologicalsort -hashEdgeList $src
# write-host "Test6"
# $a = @{collectionID = '123'; keyID='a'};$b = @{collectionID = '123'; keyID='b'};$c = @{collectionID = '123'; keyID='c'};$d = @{collectionID = '123'; keyID='d'};$e = @{collectionID = '123'; keyID='e'};
# $f = @{collectionID = '456'; keyID='f'};
# $src = @{$a = @(); $b= @($a); $c=@($a,$b); $d=@($a,$b); $e=@($a,$b,$c); $f=@()};get-topologicalsort -hashEdgeList $src -hashElementStringSeperator ':::'
# write-host "Test7"
# $a = @{collectionID = '123'; keyID='a'};$b = @{collectionID = '123'; keyID='b'};$c = @{collectionID = '123'; keyID='c'};$d = @{collectionID = '123'; keyID='d'};$e = @{collectionID = '123'; keyID='e'};
# $f = @{collectionID = '456'; keyID='f'};$g = @{collectionID = '456'; keyID='g'};
# $src = @{$a = @(); $b= @($a); $c=@($a,$b); $d=@($a,$b); $e=@($a,$b,$c); $f=@(); $g=@($f,$e)};get-topologicalsort -hashEdgeList $src -hashElementStringSeperator ':::'


###

  # switch ($PsCmdlet.ParameterSetName) {
  #     'KeyValuesAreStrings' {
      # }
      # 'KeyValuesAreHashs' {
      #     # turn the edge list into strings
      #     $keyStr = New-Object System.Text.StringBuilder
      #     #$nodeDependsUponAsString = New-Object System.Text.StringBuilder
      #     foreach ($currentNode in $hashEdgeList.Keys) {
      #         $keyStr += $($currentNode.CollectionID).ToString(); $keyStr += $hashElementStringSeperator; $keyStr += $currentNode.KeyID
      #         $DependsUponAsStrings = New-Object System.Collections.ArrayList
      #         if (  $hashEdgeList[$currentNode].ContainsKey('DependsUpon')) {
      #             #$nodeDependsUponAsString = $nodeDependsUpon # $nodeDependsUponAsString += $nodeDependsUpon.CollectionID.ToString(); $nodeDependsUponAsString += $hashElementStringSeperator; $nodeDependsUponAsString += $nodeDependsUpon.KeyID
      #             $DependsUponAsStrings.Add($nodeDependsUpon)
      #             #$DependsUponAsStrings.Add($nodeDependsUponAsString)
      #             # for ($index = 0; $index -lt $hashEdgeList[$currentNode]['DependsUpon'].count; $index++) {
      #             #     $nodeDependsUpon = $hashEdgeList[$currentNode]['DependsUpon'][$index]
      #             #     $nodeDependsUponAsString += $nodeDependsUpon.CollectionID.ToString(); $nodeDependsUponAsString += $hashElementStringSeperator; $nodeDependsUponAsString += $nodeDependsUpon.KeyID
      #             #     $DependsUponAsStrings.Add($nodeDependsUponAsString)
      #             # }
      #         }
      #         $currentEdgeList[$keyStr] = $DependsUponAsStrings
      #         $keyStr.Clear
      #         #$DependsUponAsStrings.Clear
      #     }
      # }
  # }

    #   for ($index=0;$index -lt $topologicallySortedElements.count; $index++) {
  #     Write-PSFMessage  -Level Important -Message "index = $index : topologicallySortedElements[$index] = $($topologicallySortedElements[$index].Keys)"
  #   }

