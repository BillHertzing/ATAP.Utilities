<#
.SYNOPSIS
Parses GitHub Copilot (panel) chat history exports into paired objects.

.DESCRIPTION
Reads a Copilot Chat panel export (.json/.jsonc) or Markdown/plain text and produces an array of:
Index, UserRequest, CopilotResponse (Markdown), RequestTime, ResponseTime.
For Copilot panel JSON: reads root.requests[].message.text and the model reply from
result.metadata.toolCallRounds[].response (preferred) or stitches response[].value + inlineReference.

.EXAMPLE
ConvertFrom-CopilotChatHistory -Path '.\AI Copilot Chat from SharedVSCode.jsonc' -AggressiveBoilerplateTrim

.EXAMPLE
Get-Content .\chat.jsonc -Raw | ConvertFrom-CopilotChatHistory

.INPUTS
System.String

.OUTPUTS
PSCustomObject (Index, UserRequest, CopilotResponse, RequestTime, ResponseTime)

.NOTES
Requires PSFramework for Write-PSFMessage.
Module: CopilotChatTools

.AUTHOR
AI Generated ChatGPT-5 via CoPilot. Pretty close first draft
prompted by "Write a PowerShell function to parse GitHub Copilot chat history exports into paired objects."
08122025 Whertzing for ATAP.org

#>
function ConvertFrom-CopilotChatHistory {
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
  [Alias()]
  [OutputType([Object])]
  Param(
    [Parameter(Mandatory = $false, ParameterSetName = 'ByPath', Position = 0, ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Path,

    [Parameter(Mandatory = $false, ParameterSetName = 'ByText', ValueFromPipeline = $true)]
    [string]$RawText,

    [int]$MaxResponseChars = 4000,
    [int]$MaxCodeFenceLines = 200,
    [switch]$KeepAllCode,
    [switch]$ExcludeSystem,
    [switch]$AggressiveBoilerplateTrim
  )

  BEGIN {
    $moduleName = 'ATAP.Utilities.Powershell'
    Write-PSFMessage -FunctionName 'ConvertFrom-CopilotChatHistory' -ModuleName $moduleName -Level Debug -Message 'Entering Function ConvertFrom-CopilotChatHistory in module CopilotChatTools'

    function Convert-Newline {
      param([string]$s)
      try { return ($s -replace "`r`n|`r", "`n") }
      catch {
        $_errorMessage = "Failed to normalize newlines. Exception: $($_.Exception.Message)"
        Write-PSFMessage -FunctionName 'Convert-Newline' -ModuleName $moduleName -Level Error -Message $_errorMessage
        throw $_
      }
      finally { Write-PSFMessage -FunctionName 'Convert-Newline' -ModuleName $moduleName -Level Verbose -Message "Leaving function: Convert-Newline" }
    }

    function Collapse-BlankLines {
      param([string]$s)
      try {
        ($s -split "`n" | ForEach-Object { $_.TrimEnd() }) `
        | ForEach-Object -Begin { $script:_prevBlank = $false } -Process {
          if ([string]::IsNullOrWhiteSpace($_)) { if (-not $script:_prevBlank) { $script:_prevBlank = $true; "" } }
          else { $script:_prevBlank = $false; $_ }
        } | Where-Object { $_ -ne $null } | Out-String
      }
      catch {
        $_errorMessage = "Failed to collapse blank lines. Exception: $($_.Exception.Message)"
        Write-PSFMessage -FunctionName 'Collapse-BlankLines' -ModuleName $moduleName -Level Error -Message $_errorMessage
        throw $_
      }
      finally { Write-PSFMessage -FunctionName 'Collapse-BlankLines' -ModuleName $moduleName -Level Verbose -Message "Leaving function: Collapse-BlankLines" }
    }

    function Split-CodeAndText {
      param([string]$md)
      try {
        $md = Convert-Newline $md
        $pattern = '(?ms)```(\w+)?\n(.*?)\n```'
        $result = @(); $idx = 0
        foreach ($m in [Regex]::Matches($md, $pattern)) {
          if ($m.Index -gt $idx) { $result += [PSCustomObject]@{ type = 'text'; lang = $null; value = $md.Substring($idx, $m.Index - $idx) } }
          $result += [PSCustomObject]@{
            type = 'code'; lang = ($m.Groups[1].Value); value = $m.Groups[2].Value.TrimEnd()
          }
          $idx = $m.Index + $m.Length
        }
        if ($idx -lt $md.Length) { $result += [PSCustomObject]@{ type = 'text'; lang = $null; value = $md.Substring($idx) } }
        $result
      }
      catch {
        $_errorMessage = "Failed to split code/text. Exception: $($_.Exception.Message)"
        Write-PSFMessage -FunctionName 'Split-CodeAndText' -ModuleName $moduleName -Level Error -Message $_errorMessage
        throw $_
      }
      finally { Write-PSFMessage -FunctionName 'Split-CodeAndText' -ModuleName $moduleName -Level Verbose -Message "Leaving function: Split-CodeAndText" }
    }

    $script:BoilerplatePatterns = @(
      '^\s*(sure|certainly|of course|no problem|happy to)\b.*$',
      '^\s*i (can|could|will|am going to) (help|assist|provide).*$',
      '^\s*as an ai(\s+language\s+model)?\b.*$',
      '^\s*note:\s*.*$',
      '^\s*disclaimer:\s*.*$'
      # '^\s*here(?:\'s| is)\s+(how|what|the)\b.*$',
      # '^\s*let\'s\b.*$',
      # '^\s*i (can(\'t)?|cannot)\s+(access|browse).*$'
    )

    function Trim-BoilerplateLines {
      param([string]$text, [switch]$Aggressive, [int]$MaxCodeFenceLines, [switch]$KeepAllCode)
      try {
        $blocks = Split-CodeAndText $text
        $out = New-Object System.Text.StringBuilder
        foreach ($b in $blocks) {
          if ($b.type -eq 'code') {
            [void]$out.AppendLine("$($b.lang)")
            $lines = $b.value -split "`n"
            if ($MaxCodeFenceLines -gt 0 -and -not $KeepAllCode) { $lines = $lines | Select-Object -First $MaxCodeFenceLines }
            [void]$out.AppendLine(($lines -join "`n")); [void]$out.AppendLine("``````")
          }
          else {
            $lines = ($b.value -split "`n")
            $kept = foreach ($ln in $lines) {
              $l = $ln.TrimEnd()
              if (-not $Aggressive) { $l } else {
                if ($l -match '^\s*$') { $l; continue }
                $drop = $false; foreach ($pat in $script:BoilerplatePatterns) { if ($l -imatch $pat) { $drop = $true; break } }
                if (-not $drop) { $l }
              }
            }
            [void]$out.AppendLine(($kept -join "`n"))
          }
        }
        (Collapse-BlankLines ($out.ToString().Trim())).Trim()
      }
      catch {
        $_errorMessage = "Failed to trim boilerplate. Exception: $($_.Exception.Message)"
        Write-PSFMessage -FunctionName 'Trim-BoilerplateLines' -ModuleName $moduleName -Level Error -Message $_errorMessage
        throw $_
      }
      finally { Write-PSFMessage -FunctionName 'Trim-BoilerplateLines' -ModuleName $moduleName -Level Verbose -Message "Leaving function: Trim-BoilerplateLines" }
    }

    function _Keep-ImportantMarkdown {
      param([string]$md, [int]$maxChars, [int]$MaxCodeFenceLines, [switch]$KeepAllCode)
      try {
        if ($maxChars -le 0) { return $md }
        $blocks = _Split-CodeAndText $md
        $builder = New-Object System.Text.StringBuilder
        foreach ($b in $blocks) {
          if ($b.type -eq 'code') {
            [void]$builder.AppendLine("``````$($b.lang)")
            $lines = $b.value -split "`n"
            if ($MaxCodeFenceLines -gt 0 -and -not $KeepAllCode) { $lines = $lines | Select-Object -First $MaxCodeFenceLines }
            [void]$builder.AppendLine(($lines -join "`n")); [void]$builder.AppendLine("``````")
          }
          else {
            foreach ($ln in ($b.value -split "`n")) {
              if ($ln -match '^\s*#' -or $ln -match '^\s*[-*]\s+' -or $ln -match '^\s*\d+\.\s+') { [void]$builder.AppendLine($ln.TrimEnd()); continue }
              if ($ln.Trim().Length -gt 0) { [void]$builder.AppendLine($ln.TrimEnd()) }
            }
          }
          if ($builder.Length -ge $maxChars) { break }
        }
        $out = _Collapse-BlankLines ($builder.ToString().Substring(0, [Math]::Min($builder.Length, $maxChars)))
        $out.Trim()
      }
      catch {
        $_errorMessage = "Failed to condense Markdown. Exception: $($_.Exception.Message)"
        Write-PSFMessage -FunctionName '_Keep-ImportantMarkdown' -ModuleName $moduleName -Level Error -Message $_errorMessage
        throw $_
      }
      finally { Write-PSFMessage -FunctionName '_Keep-ImportantMarkdown' -ModuleName $moduleName -Level Verbose -Message "Leaving function: _Keep-ImportantMarkdown" }
    }

    # --- NEW: robust JSONC cleaner (remove comments, trim trailing junk after final "}")
    function _Clean-JsoncText {
      param([string]$text)
      try {
        $t = _Convert-Newline $text
        # Keep only from first "{" to last "}"
        $first = $t.IndexOf('{'); $last = $t.LastIndexOf('}')
        if ($first -lt 0 -or $last -lt 0 -or $last -lt $first) { throw "Could not locate JSON object boundaries." }
        $t = $t.Substring($first, $last - $first + 1)
        # Strip /* */ and // comments
        $t = [Regex]::Replace($t, '(?s)/\*.*?\*/', '')
        $t = [Regex]::Replace($t, '(?m)^\s*//.*$', '')
        return $t.Trim()
      }
      catch {
        $_errorMessage = "Failed to clean JSONC text. Exception: $($_.Exception.Message)"
        Write-PSFMessage -FunctionName '_Clean-JsoncText' -ModuleName $moduleName -Level Error -Message $_errorMessage
        throw $_
      }
      finally { Write-PSFMessage -FunctionName '_Clean-JsoncText' -ModuleName $moduleName -Level Verbose -Message "Leaving function: _Clean-JsoncText" }
    }

    function TryParse-Json {
      param([string]$text, [ref]$json)
      try {
        $json.Value = $text | ConvertFrom-Json -Depth 200
        return $true
      }
      catch {
        # need logging here
        return $false
      }
      finally { Write-PSFMessage -FunctionName 'TryParse-Json' -ModuleName $moduleName -Level Verbose -Message "Leaving function: TryParse-Json" }
    }

    # --- NEW: Copilot panel extractor for your sample schema
    function Get-PairsFromCopilotRequests {
      param($root)
      try {
        if (-not $root.requests) { return @() }
        $pairs = @()
        $i = 0
        foreach ($req in $root.requests) {
          $userText = $req.message.text
          # Prefer canonical stitched response if available
          $rounds = $req.result.metadata.toolCallRounds
          $assistant =
          if ($rounds -and $rounds.Count -gt 0 -and $rounds[0].response) {
            [string]$rounds[0].response
          }
          else {
            # Fallback: stitch response[].value and format inlineReference entries
            $sb = New-Object System.Text.StringBuilder
            foreach ($r in ($req.response | ForEach-Object { $_ })) {
              if ($r.kind -eq 'inlineReference' -and $r.inlineReference) {
                $p = $r.inlineReference.fsPath ?? $r.inlineReference.path
                if ($p) { [void]$sb.Append("``$($p)``") }
              }
              elseif ($null -ne $r.value) {
                [void]$sb.Append($r.value)
              }
            }
            $sb.ToString()
          }

          # times: request.timestamp is ms since Unix epoch. response time unknown -> use same or null
          $reqTime = $null
          try {
            if ($req.timestamp) { $reqTime = [DateTimeOffset]::FromUnixTimeMilliseconds([int64]$req.timestamp).LocalDateTime }
          }
          catch { $reqTime = $null }

          $pairs += [PSCustomObject]@{
            Index           = $i
            UserRequest     = [string]$userText
            CopilotResponse = [string]$assistant
            RequestTime     = $reqTime
            ResponseTime    = $reqTime
          }
          $i++
        }
        $pairs
      }
      catch {
        $_errorMessage = "Failed to extract pairs from Copilot requests[]. Exception: $($_.Exception.Message)"
        Write-PSFMessage -FunctionName 'Get-PairsFromCopilotRequests' -ModuleName $moduleName -Level Error -Message $_errorMessage
        throw $_
      }
      finally { Write-PSFMessage -FunctionName 'Get-PairsFromCopilotRequests' -ModuleName $moduleName -Level Verbose -Message "Leaving function: Get-PairsFromCopilotRequests" }
    }

    # legacy/other formats
    function Get-PairsFromJson {
      param($json, [switch]$ExcludeSystem)
      try {
        $msgs = @()
        if ($json -is [System.Collections.IEnumerable] -and -not ($json.PSObject.TypeNames -contains 'System.Collections.Hashtable')) { $arr = $json }
        elseif ($null -ne $json.messages) { $arr = $json.messages }
        else { $arr = @(); if ($json.conversations) { foreach ($c in $json.conversations) { $arr += $c.messages } } }

        foreach ($m in $arr) {
          $role = $m.role ?? $m.sender ?? $m.author ?? $m.from
          $content = $m.content ?? $m.text ?? $m.message ?? $m.body
          if ($null -eq $content) { continue }
          $ts = $m.timestamp ?? $m.created_at ?? $m.time ?? $m.date
          $msgs += [PSCustomObject]@{ role = ($role -as [string]).ToLowerInvariant(); content = [string]$content; ts = $ts }
        }
        if ($ExcludeSystem) { $msgs = $msgs | Where-Object { $_.role -notin @('system', 'tool') } }

        $pairs = @()
        for ($i = 0; $i -lt $msgs.Count; $i++) {
          if ($msgs[$i].role -match 'user|you') {
            $j = $i + 1; while ($j -lt $msgs.Count -and -not ($msgs[$j].role -match 'assistant|copilot|bot|assistant_role')) { $j++ }
            if ($j -lt $msgs.Count) {
              $pairs += [PSCustomObject]@{
                Index           = [int]$pairs.Count
                UserRequest     = ($msgs[$i].content | Out-String).Trim()
                CopilotResponse = ($msgs[$j].content | Out-String).Trim()
                RequestTime     = $msgs[$i].ts
                ResponseTime    = $msgs[$j].ts
              }
              $i = $j
            }
          }
        }
        $pairs
      }
      catch {
        $_errorMessage = "Failed to extract pairs from generic JSON. Exception: $($_.Exception.Message)"
        Write-PSFMessage -FunctionName 'Get-PairsFromJson' -ModuleName $moduleName -Level Error -Message $_errorMessage
        throw $_
      }
      finally { Write-PSFMessage -FunctionName 'Get-PairsFromJson' -ModuleName $moduleName -Level Verbose -Message "Leaving function: Get-PairsFromJson" }
    }

    function Get-PairsFromText {
      param([string]$text)
      try {
        $t = _Convert-Newline $text
        $lines = $t -split "`n"
        $currentRole = $null; $buffers = @(); $buf = New-Object System.Text.StringBuilder
        function Clear-Buffer {
          param([string]$role, [ref]$bufRef)
          try {
            $s = $bufRef.Value.ToString().Trim()
            if ($s.Length -gt 0) { $script:buffers += [PSCustomObject]@{ role = $role; content = $s } }
            $bufRef.Value.Clear() | Out-Null
          }
          catch {
            $_errorMessage = "Failed to clear accumulation buffer. Exception: $($_.Exception.Message)"
            Write-PSFMessage -FunctionName 'Clear-Buffer' -ModuleName $moduleName -Level Error -Message $_errorMessage
            throw $_
          }
          finally {
            Write-PSFMessage -FunctionName 'Clear-Buffer' -ModuleName $moduleName -Level Verbose -Message "Leaving function: Clear-Buffer"
          }
        }
        foreach ($ln in $lines) {
          if ($ln -match '^\s*(\*\*?(User|You)\*?\*?:|#\s*(User|You)\b|User\s*:|You\s*:)\s*$') { if ($currentRole) { Clear-Buffer -role $currentRole ([ref]$buf) }; $currentRole = 'user'; continue }
          if ($ln -match '^\s*(\*\*?(Assistant|Copilot)\*?\*?:|#\s*(Assistant|Copilot)\b|Assistant\s*:|Copilot\s*:)\s*$') { if ($currentRole) { Clear-Buffer -role $currentRole ([ref]$buf) }; $currentRole = 'assistant'; continue }
          [void]$buf.AppendLine($ln)
        }
        if ($currentRole) { Clear-Buffer -role $currentRole ([ref]$buf) }

        $pairs = @(); for ($i = 0; $i -lt $buffers.Count; $i++) {
          if ($buffers[$i].role -eq 'user') {
            for ($j = $i + 1; $j -lt $buffers.Count; $j++) {
              if ($buffers[$j].role -eq 'assistant') {
                $pairs += [PSCustomObject]@{
                  Index = [int]$pairs.Count; UserRequest = $buffers[$i].content; CopilotResponse = $buffers[$j].content; RequestTime = $null; ResponseTime = $null
                }; $i = $j; break
              }
            }
          }
        }; $pairs
      }
      catch {
        $_errorMessage = "Failed to extract pairs from text. Exception: $($_.Exception.Message)"
        Write-PSFMessage -FunctionName 'Get-PairsFromText' -ModuleName $moduleName -Level Error -Message $_errorMessage
        throw $_
      }
      finally { Write-PSFMessage -FunctionName 'Get-PairsFromText' -ModuleName $moduleName -Level Verbose -Message "Leaving function: Get-PairsFromText" }
    }
  }

  PROCESS {
    if ($PSCmdlet.ShouldProcess("Parsing chat history", "Convert to paired objects")) {
      try {
        Write-PSFMessage -FunctionName 'ConvertFrom-CopilotChatHistory' -ModuleName $moduleName -Level Important -Message 'Starting transcript parse and condensation'

        $text =
        if ($PSCmdlet.ParameterSetName -eq 'ByText' -and $PSBoundParameters.ContainsKey('RawText')) {
          _Convert-Newline $RawText
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'ByPath' -and $PSBoundParameters.ContainsKey('Path')) {
          $raw = [System.IO.File]::ReadAllText((Resolve-Path $Path))
          _Convert-Newline $raw
        }
        else { throw "You must provide either -Path or -RawText." }

        # Try Copilot JSONC first (your sample)
        $pairs = @()
        $jsonRoot = $null
        $clean = $null
        if ($text -match '\"requests\"\s*:') {
          try {
            $clean = _Clean-JsoncText $text
            if (TryParse-Json -text $clean -json ([ref]$jsonRoot)) {
              $pairs = Get-PairsFromCopilotRequests -root $jsonRoot
            }
          }
          catch {
            # fall through to other parsers after logging
            $_errorMessage = "Primary Copilot JSONC parse path failed. Exception: $($_.Exception.Message)"
            Write-PSFMessage -FunctionName 'ConvertFrom-CopilotChatHistory' -ModuleName $moduleName -Level Error -Message $_errorMessage
          }
        }

        if (-not $pairs -or $pairs.Count -eq 0) {
          $jsonGeneric = $null
          if (TryParse-Json -text $text -json ([ref]$jsonGeneric)) {
            $pairs = Get-PairsFromJson -json $jsonGeneric -ExcludeSystem:$ExcludeSystem
          }
          else {
            $pairs = Get-PairsFromText -text $text
          }
        }

        # Clean + condense assistant responses
        $out = foreach ($p in $pairs) {
          $user = ($p.UserRequest | Out-String).Trim()
          $assistant = ($p.CopilotResponse | Out-String).Trim()

          $assistant = Trim-BoilerplateLines -text $assistant -Aggressive:$AggressiveBoilerplateTrim `
            -MaxCodeFenceLines:$MaxCodeFenceLines -KeepAllCode:$KeepAllCode

          $assistant = _Keep-ImportantMarkdown -md $assistant -maxChars $MaxResponseChars `
            -MaxCodeFenceLines:$MaxCodeFenceLines -KeepAllCode:$KeepAllCode

          $user = ($user -replace '^\s*(?:thanks|thank you).*$', '' -ireplace '^\s*please\s*', '').Trim()

          [PSCustomObject]@{
            Index           = $p.Index
            UserRequest     = $user
            CopilotResponse = $assistant
            RequestTime     = $p.RequestTime
            ResponseTime    = $p.ResponseTime
          }
        }

        Write-PSFMessage -FunctionName 'ConvertFrom-CopilotChatHistory' -ModuleName $moduleName -Level Important -Message "Parsed $($out.Count) conversation pair(s)"
        $out
      }
      catch {
        $_errorMessage = "Failed to parse and convert chat history. Exception: $($_.Exception.Message)"
        Write-PSFMessage -FunctionName 'ConvertFrom-CopilotChatHistory' -ModuleName $moduleName -Level Error -Message $_errorMessage
        $errorMessage = "A description of the operation that was attempted and failed: parse chat history and convert to objects. Exception: $($_.Exception.Message)"
        Write-PSFMessage -FunctionName 'ConvertFrom-CopilotChatHistory' -ModuleName $moduleName -Level Error -Message $errorMessage -Exception $_.Exception
        throw $_
      }
      finally {
        Write-PSFMessage -FunctionName 'ConvertFrom-CopilotChatHistory' -ModuleName $moduleName -Level Verbose -Message "Leaving function: ConvertFrom-CopilotChatHistory"
      }
    }
  }

  END {
    Write-PSFMessage -FunctionName 'ConvertFrom-CopilotChatHistory' -ModuleName $moduleName -Level Debug -Message 'Leaving Function ConvertFrom-CopilotChatHistory in module CopilotChatTools'
  }
}
