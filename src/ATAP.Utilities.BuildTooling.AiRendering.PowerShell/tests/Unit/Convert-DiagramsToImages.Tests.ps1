BeforeAll {
  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage {
      param([Parameter(ValueFromRemainingArguments = $true)] $Rest)
    }
  }
  . "$PSScriptRoot\..\..\public\Convert-DiagramsToImages.ps1"
}

AfterAll {
  Remove-Item Function:\Write-PSFMessage -Force -ErrorAction SilentlyContinue
}

Describe 'Convert-DiagramsToImages [public]' -Tag 'Unit' {
  It 'plans a PlantUML render beneath the requested generated output root' {
    $repo = Join-Path $TestDrive 'repo'
    $diagramRoot = Join-Path $repo 'Documentation'
    $outputRoot = Join-Path $repo '_generated\diagrams'
    $jar = Join-Path $TestDrive 'plantuml.jar'
    New-Item -ItemType Directory -Path (Join-Path $repo '.git'), $diagramRoot -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $diagramRoot 'flow.puml') -Value '@startuml'
    Set-Content -LiteralPath $jar -Value 'fixture'

    Push-Location $repo
    try {
      $result = Convert-DiagramsToImages -Path $diagramRoot -OutputRoot $outputRoot `
        -PlantUmlJar $jar -WhatIf
    } finally {
      Pop-Location
    }

    $result.Kind | Should -Be 'PlantUML'
    $result.Format | Should -Be 'PNG'
    $result.Output | Should -Be (Join-Path $outputRoot 'Documentation\flow.png')
  }
}
