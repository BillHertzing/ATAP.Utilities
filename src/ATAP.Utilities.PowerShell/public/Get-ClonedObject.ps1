# From [Get-ClonedObject.ps1](https://github.com/RamblingCookieMonster/PSDeploy/blob/master/PSDeploy/Private/Get-ClonedObject.ps1)
# By [RamblingCookieMonster](https://github.com/RamblingCookieMonster)
# Idea from [deep-copy-a-dictionary-hashtable-in-powershell](http://stackoverflow.com/questions/7468707/deep-copy-a-dictionary-hashtable-in-powershell)
# borrowed from http://stackoverflow.com/questions/8982782/does-anyone-have-a-dependency-graph-and-topological-sorting-code-snippet-for-pow
function Get-ClonedObject {
  param($DeepCopyObject)
  $memStream = new-object IO.MemoryStream
  $formatter = new-object Runtime.Serialization.Formatters.Binary.BinaryFormatter
  $formatter.Serialize($memStream,$DeepCopyObject)
  $memStream.Position=0
  $formatter.Deserialize($memStream)
}
