BeforeAll {
    . $PSCommandPath.Replace('.Tests.ps1', '.ps1')
}

Describe "Get-CoreInfo.UnitTest" {
    It "Returns expected output" {
        Get-CoreInfo.UnitTest | Should -Be "YOUR_EXPECTED_VALUE"
    }
}
