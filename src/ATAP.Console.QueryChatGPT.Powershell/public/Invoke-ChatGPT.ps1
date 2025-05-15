param (
  [Parameter(Mandatory = $true)]
  [string]$Prompt
)

# Your OpenAI API key (you can also store this in a secure location)

# Choose model: gpt-3.5-turbo, gpt-4, or gpt-4-turbo
$model = "gpt-4.1-nano-2025-04-14"

# Prepare request body as a JSON string
$body = @{
  model       = $model
  messages    = @(
    @{
      role    = "user"
      content = $Prompt
    }
  )
  temperature = 0.7
} | ConvertTo-Json -Depth 10

# Set headers
# ToDO: Get CHATGPT_API_TOKEN from a vault
# Today, get it from an environment variable
$headers = @{
  "Content-Type"  = "application/json"
  "Authorization" = "Bearer $env:CHATGPT_API_TOKEN"
}

# ToDO: Get CHATGPT_API_TOKEN from a vault
# Today, get it from an environment variable
# $env:CHATGPT_API_TOKEN
# Call OpenAI API
try {
  $response = Invoke-RestMethod `
    -Uri $global:settings[$global:configRootKeys['CHATGPT_URLConfigRootKey']] `
    -Method Post `
    -Headers $headers `
    -Body $body
}
catch {
  Write-Error "response.err: $response.error"
}
# Output the response content
$response.choices[0].message.content
pause
