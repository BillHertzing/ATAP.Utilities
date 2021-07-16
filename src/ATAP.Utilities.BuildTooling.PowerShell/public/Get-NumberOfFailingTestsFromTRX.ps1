Function Get-NumberOfFailingTestsFromTRX ( [string] $xmlInputFile )
{
    $xml = [Xml](Get-Content $xmlInputFile)

    # <ResultSummary outcome="Failed">
    #   <Counters total="652" executed="650" passed="630" failed="20" error="0" timeout="0" aborted="0" inconclusive="0" passedButRunAborted="0" notRunnable="0" notExecuted="0" disconnected="0" warning="0" completed="0" inProgress="0" pending="0" />
    #   ...

    $ns = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
    # our input mstest XML is per this schema
    $xmlNamespace = "http://microsoft.com/schemas/VisualStudio/TeamTest/2010"
    $ns.AddNamespace("ns", $xmlNamespace)

    $xpath = "//ns:ResultSummary/ns:Counters" # xpath when namespaces exists
    $resultSummary = $xml.SelectSingleNode($xpath, $ns)

    return $resultSummary.failed
}
