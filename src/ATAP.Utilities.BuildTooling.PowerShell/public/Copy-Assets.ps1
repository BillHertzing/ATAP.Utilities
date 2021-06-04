#
# CopyAssets.ps1
# see https://stackoverflow.com/questions/45220194/publish-profile-copy-files-to-relative-destination
#
[CmdletBinding()]
Param(
    [Parameter(Mandatory=$True)]
    [string]$solutionDirectory,

    [Parameter(Mandatory=$True)]
    [string]$copyTo
)

#
# Copy Assets Initializations
#
# Absolute path to copy files to and create folders in
$absolutePath = @($copyTo + "/App_Config/Include")
# Set paths we will be copy files from
$featureDirectory = Join-Path $solutionDirectory "/Feature/*/App_Config/Include"
$foundationDirectory = Join-Path $solutionDirectory "/Foundation/*/App_Config/Include"

function Create-Files {
    Param ([string]$currentPath, [string]$pathTo)
    Write-Host "Attempting to create files..."
    # Copy files from root include folder
    $files = Get-ChildItem -Path $currentPath | Where-Object {$_.PSIsContainer -eq $false}

    foreach ($file in $files)
    {
        Write-Host "Attempting to copy file:"$file "to"$path
        New-Item -ItemType File -Path $pathTo -Name $file.Name -Force
    }
}

# Logic to create new directories and copy files over.
function Copy-Assets {

    Param ([string]$directoryBase)
    $path = $absolutePath
    Write-Host "Directory copying from:" $directoryBase
    Write-Host "Creating files found in include folder"
    # Path hack to copy files from directoryBase
    $directoryBaseHack = Join-Path $directoryBase "\*"
    Create-Files -currentPath $directoryBaseHack -pathTo $path
    Write-Host "Getting sub directories to copy from"
    $directories = Get-ChildItem -Path $directoryBase -Recurse | Where-Object {$_.PSIsContainer -eq $true}
    Write-Host "Iterating through directories"
    foreach ($directory in $directories)
    {
        Write-Host "Checking if directory"$directory.Name "is part of absolute path."
        if($absolutePath -match $directory.Name)
        {
            # checking if directory already exists
            Write-Host "Directory is part of absolute path, confirming if path exists"
            $alreadyExists = Test-Path $absolutePath
            if(!$alreadyExists)
            {       
                Write-Host "Absolute path doesn't exist creating..."
                New-Item -ItemType Directory -Path $absolutePath -Force
                Write-Host "All directories in path for Absolute Path created:"$absolutePath
            }
            Write-Host "Directory for"$directory.Name "already exists as it is part of the Absolute Path:" $absolutePath
        }else{
            Write-Host "Joining path with absolute path"
            $path = Join-Path $absolutePath $directory.Name
            Write-Host "Joined path:"$path

            Write-Host "Does joined path exist:"$path
            $alreadyExists = Test-Path $path
            if(!$alreadyExists)
            {       
                Write-Host "Joined path doesn't exist creating..."
                New-Item -ItemType Directory -Path $path -Force
                Write-Host "Created new directory:" $path
            }
            Write-Host "Directory for"$path "already exists."
        }
        Write-Host "Creating files found in:" $directory
        Create-Files -currentPath $directory -pathTo $path
    }
}
Write-Host "Starting Copying Foundation Files"
Copy-Assets -directoryBase $foundationDirectory
Write-Host "Starting Copying Feature Files"
Copy-Assets -directoryBase $featureDirectory