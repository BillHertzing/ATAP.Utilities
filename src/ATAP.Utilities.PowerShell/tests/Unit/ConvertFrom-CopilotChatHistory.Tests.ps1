Describe 'ConvertFrom-CopilotChatHistory' -Tag 'Unit', 'Disabled' {
  Context 'When provided with valid JSON input' {
    It 'Should parse the input and return paired objects' {
      $jsonInput = @"
            {
                "requests": [
                    {
                        "message": { "text": "User request text" },
                        "result": {
                            "metadata": {
                                "toolCallRounds": [
                                    { "response": "Copilot response text" }
                                ]
                            }
                        },
                        "timestamp": 1696982400000
                    }
                ]
            }
"@

      $expectedTime = Get-Date -Date "2023-10-11T00:00:00Z"

      $result = @(ConvertFrom-CopilotChatHistory -RawText $jsonInput)

      $result | Should -HaveCount 1
      $result[0].Index | Should -Be 0
      $result[0].UserRequest | Should -BeExactly "User request text"
      $result[0].CopilotResponse | Should -BeExactly "Copilot response text"
      $result[0].RequestTime | Should -Be $expectedTime
      $result[0].ResponseTime | Should -Be $expectedTime
    }
  }

  Context 'When provided with invalid input' {
    It 'Should throw an error' {
      $invalidInput = "Invalid JSON"

      { ConvertFrom-CopilotChatHistory -RawText $invalidInput } | Should -Throw
    }
  }
}
