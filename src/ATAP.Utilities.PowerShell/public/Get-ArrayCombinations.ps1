function Get-ArrayCombinations {
  [cmdletbinding()]
  param (
    [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0, ValueFromPipelineByPropertyName = $true )]
   # [ValidateScript({$_.count -gt 1}, ErrorMessage = "inputArray must have at least two elements")]
    [object[]] $inputArray
  )
  Begin {}
  Process {
  $outputPairsArray = [System.Collections.ArrayList]@()
  for ($i = 0; $i -lt $($inputArray.count - 1); $i++) {
    for ($j = $i + 1; $j -lt $inputArray.count; $j++) {
      [void]$outputPairsArray.add( @($inputArray[$i], $inputArray[$j]))
    }
  }

  $outputPairsArray
}
end{}
}
