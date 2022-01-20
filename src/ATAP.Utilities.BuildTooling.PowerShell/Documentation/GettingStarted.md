# Powershell module and scripts for building code and blogs

## Blog Post Image Pipeline

[Set hosting solution variables]
[Set media Queries parameters]
[Define cache and persistent storage of the dropboxlinks created by this process]

[paramters 'original file location, hosting solution's Blog Post Images location manifestation in a locally-accessable location]

Create List of file names in the hosting solution's Blog Post Images location manifestation

map transform {list of unique filenames sans `\(\d+). iterate this list
  identify the latest copy of each basename in the , compare to latest dropboxlinks in cache/persistent storage. identify discrepancies. remove all others with the same basename. report discrepancies
  rename the latest writetime to the base name
  copy attributes from the original to the latest copy
  remove ppi attributes
  iterate for number of mediaquerys needed
    create copies based on the width and height attributes, and the mediaquery parameter set's needs
    run the original through the VIP lib to resize it, and store the new image in a filename that follows the mediaquery convention for 'small', 'tablet', 'desktop', ...
  }
  Create a new sharing dropboxlink for each file that does not yet have a sharing link.
  Update the cache and persistent storage of dropboxlinks
  Create the list of links and report it
  Create the Gallery code block to incorporate into the YAML section of the blog post


## Diff-BlogImageList

## Get-ModulesForUserProfileAsSymbolicLinks

## Rename-FilesDuplicatedAndMoved

## Copy-AttributesOfOther Files

## Build-ImageFromPlantUML.ps1


