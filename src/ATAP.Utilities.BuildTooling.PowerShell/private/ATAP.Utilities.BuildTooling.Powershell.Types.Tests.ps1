# Import the private function being tested
. ..\Private\MyPrivateFunction.ps1

Describe "MyPrivateFunction" {
    It "Tests the MyPrivateFunction" {
        # Test MyPrivateFunction using It block
        MyPrivateFunction | Should -Be "ExpectedOutput"
    }

    # Add more test cases as needed
}





