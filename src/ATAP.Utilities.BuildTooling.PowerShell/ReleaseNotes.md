# Production Release Notes in Chronological order

## 0.2.0 - VersionJsonAsCeiling (Sprint 0007)

- Added `CurrentTier`, `CeilingTier`, and `IsAtCeiling` to `Get-BuildContext`.
- Kept `Get-BuildContext.Tier` as a deprecated alias for `CeilingTier`.
- Added `Get-TierOrder` and `Test-PromotionWithinCeiling`.
- Added optional `-CeilingTier` guard support to `Promote-ProGetPackage`.
- Updated `Get-TierFromNBGVLabel` compatibility behavior for feature-label ceilings and canonical `Production` tier naming.

## Template ToDo: Fix up release notes template

Template for release notes, edit before production release
%moduleName%
%moduleversion%
%releasedate%
%sha256%
%checksumURL%
%SWBOM%

## 🗪 Test Coverage & Results

- **Coverage:** $Coverage% of code paths covered
- **Tests run:** $Total total
  - ✅ Passed: $Passed
  - ❌ Failed: $Failed
  - ⚠️ Skipped: $Skipped

## Must have another level 2 chapter here

stuff
