param (
  [int]$CommonCenterX,
  [int]$CommonCenterY,
  [int]$PublicRadius,
  [int]$LabelOffset = 10,
  [double]$MembersAndGuestsScale = 0.9,
  [double]$MembersScale = 0.85,
  [double]$MembersXDisplacementPercentage = 0.4,
  [double]$MembersYDisplacementPercentage = 1.15,
  [double]$GuestsScale = 0.08,
  [double]$GuestsXDisplacementPercentage = 1.0,
  [double]$GuestsYDisplacementPercentage = 0.3,
  [string]$OutputPath = "../_generated/diagram.drawio",
  [string]$TemplatePath = "./TemplateVennDiagram.xml"
)

. "../private/_LabelLocationForEllipse.ps1"

# Validate template file
if (-not (Test-Path $TemplatePath)) {
  Write-Error "Template file '$TemplatePath' not found."
  exit 1
}
# Validate output directory
$outputDir = Split-Path -Path $OutputPath -Parent
if (-not (Test-Path $outputDir)) {
  Write-Error "Output directory '$outputDir' does not exist."
  exit 1
}

# Calculate some defaults for objects on an A4 size page
$pageWidth = 827
$pageHeight = 1169
# padding so object don't go to the edge
$padding = 60
$maxDiameter = $pageWidth - (2 * $padding)
$maxradius = [math]::Round($maxDiameter / 2, 0)

# If commonCenter is not specified, use the center of the page
if (-not $CommonCenterX) {
  $CommonCenterX = [math]::Round($pageWidth / 2, 0)
}
if (-not $CommonCenterY) {
  $CommonCenterY = [math]::Round($pageHeight / 2, 0)
}
# if $PublicRadius  is not specified or is larger than the max radius, use the max radius
if (-not $PublicRadius -or $PublicRadius -gt $maxradius) {
  $PublicRadius = $maxradius
}

# The Public circle's centerpoint defines the center of the diagram
# Common center (Public circle)
$PublicCenterX = $CommonCenterX
$PublicCenterY = $CommonCenterY
$PublicDiameter = $PublicRadius * 2
# Top-left corner for ellipse placement
$PublicTopLeftCornerX = $PublicCenterX - $PublicRadius
$PublicTopLeftCornerY = $PublicCenterY - $PublicRadius
# Text label position (ESE from Public circle)
$publicLabelLocation = _LabelLocationForEllipse -XCenterEllipseCoordinate $PublicCenterX `
  -YCenterEllipseCoordinate $PublicCenterY `
  -XEllipseRadius $PublicRadius `
  -YEllipseRadius $PublicRadius `
  -LabelAngle 90 `
  -LabelDistance $LabelOffset

# $PublicLabelX = $publicLabelLocation.XCoordinate
# $PublicLabelY = $publicLabelLocation.YCoordinate

# MembersAndGuests Centerpoint is the same as the center of the Public's circle
$MembersAndGuestsCenterX = $PublicCenterX
$MembersAndGuestsCenterY = $publicCenterY
$MembersAndGuestsRadius = [math]::Round($PublicRadius * $MembersAndGuestsScale, 0)
$MembersAndGuestsDiameter = $MembersAndGuestsRadius * 2
# Top-left corner for ellipse placement
$MembersAndGuestsTopLeftCornerX = $MembersAndGuestsCenterX - $MembersAndGuestsRadius
$MembersAndGuestsTopLeftCornerY = $MembersAndGuestsCenterY - $MembersAndGuestsRadius
# Text label position (ESE from MembersAndGuests circle)
$MembersAndGuestsLabelX = $MembersAndGuestsCenterX + $MembersAndGuestsRadius + 30
$MembersAndGuestsLabelY = $MembersAndGuestsCenterY + 30
# Text label position (ESE from MembersAndGuests circle)
$membersandGuestsLabelLocation = _LabelLocationForEllipse -XCenterEllipseCoordinate $MembersAndGuestsCenterX `
  -YCenterEllipseCoordinate $MembersAndGuestsCenterY `
  -XEllipseRadius $MembersAndGuestsRadius `
  -YEllipseRadius $MembersAndGuestsRadius `
  -LabelAngle 80 `
  -LabelDistance ($LabelOffset + 20)
# $MembersAndGuestsLabelX = $membersandGuestsLabelLocation.XCoordinate
# $MembersAndGuestsLabelY = $membersandGuestsLabelLocation.YCoordinate

# calculate the radius of the Members circles
$MembersRadius = [math]::Round($MembersAndGuestsRadius * $MembersScale)

# Calculate the Members circle offset NW
$MembersCenterX = $MembersAndGuestsCenterX - [math]::Round(($MembersRadius * $MembersXDisplacementPercentage), 0)
$MembersCenterY = $MembersAndGuestsCenterY - [math]::Round(($MembersRadius * $MembersYDisplacementPercentage), 0)

# calculate the radius of the Members circles
$GuestsRadius = [math]::Round($MembersRadius * $GuestsScale)
# Calculate the Guests circle offset SE
$GuestsCenterX = $MembersAndGuestsCenterX + [math]::Round(($GuestsRadius * $GuestsXDisplacementPercentage), 0)
$GuestsCenterY = $MembersAndGuestsCenterY + [math]::Round(($GuestsRadius * $GuestsYDisplacementPercentage), 0)

# Members Centerpoint is offset NW from the Public circle's centerpoint
$MembersDiameter = $MembersRadius * 2
# Top-left corner for ellipse placement
$MembersTopLeftCornerX = $MembersCenterX - $MembersRadius
$MembersTopLeftCornerY = $MembersCenterY - $MembersRadius
# Text label position (ESE from Members circle)
$membersLabelLocation = _LabelLocationForEllipse -XCenterEllipseCoordinate $MembersCenterX `
  -YCenterEllipseCoordinate $MembersCenterY `
  -XEllipseRadius $MembersRadius `
  -YEllipseRadius $MembersRadius `
  -LabelAngle 110 `
  -LabelDistance ($LabelOffset + 30)

# Guests Centerpoint is offset SE from the Public circle's centerpoint
$GuestsDiameter = $GuestsRadius * 2
# Top-left corner for ellipse placement
$GuestsTopLeftCornerX = $GuestsCenterX - $GuestsRadius
$GuestsTopLeftCornerY = $GuestsCenterY - $GuestsRadius
# Text label position (ESE from Guests circle)
$GuestsLabelLocation = _LabelLocationForEllipse -XCenterEllipseCoordinate $GuestsCenterX `
  -YCenterEllipseCoordinate $GuestsCenterY `
  -XEllipseRadius $GuestsRadius `
  -YEllipseRadius $GuestsRadius `
  -LabelAngle 90 `
  -LabelDistance $LabelOffset
$GuestsLabelX = $labelLocationForGuests.XCoordinate
$GuestsLabelY = $labelLocationForGuests.YCoordinate

# Read template and perform token replacement
$template = Get-Content -Path $TemplatePath -Raw

$replacements = @{
  "{{PublicCenterX}}"                  = $PublicCenterX
  "{{PublicCenterY}}"                  = $PublicCenterY
  "{{PublicTopLeftCornerX}}"           = $PublicTopLeftCornerX
  "{{PublicTopLeftCornerY}}"           = $PublicTopLeftCornerY
  "{{PublicDiameter}}"                 = $PublicDiameter
  "{{PublicLabelX}}"                   = $publicLabelLocation.XCoordinate
  "{{PublicLabelY}}"                   = $publicLabelLocation.YCoordinate
  "{{MembersAndGuestsCenterX}}"        = $MembersAndGuestsCenterX
  "{{MembersAndGuestsCenterY}}"        = $MembersAndGuestsCenterY
  "{{MembersAndGuestsTopLeftCornerX}}" = $MembersAndGuestsTopLeftCornerX
  "{{MembersAndGuestsTopLeftCornerY}}" = $MembersAndGuestsTopLeftCornerY
  "{{MembersAndGuestsDiameter}}"       = $MembersAndGuestsDiameter
  "{{MembersAndGuestsLabelX}}"         = $membersandGuestsLabelLocation.XCoordinate
  "{{MembersAndGuestsLabelY}}"         = $membersandGuestsLabelLocation.YCoordinate
  "{{MembersCenterX}}"                 = $MembersCenterX
  "{{MembersCenterY}}"                 = $MembersCenterY
  "{{MembersTopLeftCornerX}}"          = $MembersTopLeftCornerX
  "{{MembersTopLeftCornerY}}"          = $MembersTopLeftCornerY
  "{{MembersDiameter}}"                = $MembersDiameter
  "{{MembersLabelX}}"                  = $membersLabelLocation.XCoordinate
  "{{MembersLabelY}}"                  = $membersLabelLocation.YCoordinate
  "{{GuestsCenterX}}"                  = $GuestsCenterX
  "{{GuestsCenterY}}"                  = $GuestsCenterY
  "{{GuestsTopLeftCornerX}}"           = $GuestsTopLeftCornerX
  "{{GuestsTopLeftCornerY}}"           = $GuestsTopLeftCornerY
  "{{GuestsDiameter}}"                 = $GuestsDiameter
  "{{GuestsLabelX}}"                   = $guestsLabelLocation.XCoordinate
  "{{GuestsLabelY}}"                   = $guestsLabelLocation.YCoordinate
}

# Perform the replacements
foreach ($key in $replacements.Keys) {
  $escapedKey = [Regex]::Escape($key)
  $template = $template -replace $escapedKey, $replacements[$key]
}
# Save to file
Set-Content -Path $OutputPath -Value $template -Encoding UTF8

Write-Host "✅ Draw.io file generated at: $OutputPath"
