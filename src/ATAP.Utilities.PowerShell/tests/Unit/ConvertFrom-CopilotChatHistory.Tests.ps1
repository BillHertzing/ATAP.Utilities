Describe 'ConvertFrom-CopilotChatHistory' {
  Context 'When provided with valid JSON input' {
    It 'Should parse the input and return paired objects' {
      $jsonInput = @"
            {
                \"requests\": [
                    {
                        \"message\": { \"text\": \"User request text\" },
                        \"result\": {
                            \"metadata\": {
                                \"toolCallRounds\": [
                                    { \"response\": \"Copilot response text\" }
                                ]
                            }
                        },
                        \"timestamp\": 1697040000000
                    }
                ]
            }
"@

      $expectedOutput = @(
        [PSCustomObject]@{
          Index           = 0
          UserRequest     = "User request text"
          CopilotResponse = "Copilot response text"
          RequestTime     = (Get-Date -Date "2023-10-11T00:00:00Z")
          ResponseTime    = (Get-Date -Date "2023-10-11T00:00:00Z")
        }
      )

      $result = ConvertFrom-CopilotChatHistory -RawText $jsonInput

      $result | Should -BeExactly $expectedOutput
    }
  }

  Context 'When provided with invalid input' {
    It 'Should throw an error' {
      $invalidInput = "Invalid JSON"

      { ConvertFrom-CopilotChatHistory -RawText $invalidInput } | Should -Throw
    }
  }
}
