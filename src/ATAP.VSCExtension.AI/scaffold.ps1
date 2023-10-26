
[System.Text.StringBuilder]$sb = [System.Text.StringBuilder]::new()
$extensionName = 'ATAP-AIAssist'
$extensionDescription = 'AI code helper'
$extensionPublisher= 'ATAPUtilities.org'

# Check for Node.js and npm
$node = Get-Command node -ErrorAction SilentlyContinue
$npm = Get-Command npm -ErrorAction SilentlyContinue

# Error if Node.js and npm if not found
if (-not $node -or -not $npm) {
  $message = 'Node.js or npm are not installed'
  Write-PSFMessage -Level Error -Message $message
  # toDo catch the errors, add to 'Problems'
  Throw $message
  # choco install nodejs -y
  # $nodeJSVersion = 'v16.13.0'
  # $nodeJSArchitecture = '-x64'
  # $nodeInstallerProtocol = 'https'
  # $nodeInstallerServer = 'nodejs.org'
  # $nodeInstallerPort = '443'
  # $nodeInstallerPath = 'C:\Dropbox\Downloads\node-v18.18.2-x64.msi'
  #  ('node-', $nodeJSVersion, $nodeJSArchitecture, '.msi') | ForEach-Object { [void]$sb.Append($_) }
  # $nodeInstallerFilename = $sb.ToString()
  # [void] $sb.Clear()
  # ('/', 'dist', '/', $nodeJSVersion, '/', $nodeInstallerFilename) | ForEach-Object { [void]$sb.Append($_) }
  # $nodeInstallerURI = [UriBuilder]::new($nodeInstallerProtocol, $nodeInstallerServer, $nodeInstallerPort, $sb.ToString())
  # [void] $sb.Clear()
  # Write-PSFMessage -Level Debug -Message "downloading $nodeInstallerURI to $nodeInstallerPath"
  # Invoke-WebRequest $nodeInstallerURI.URI -OutFile $nodeInstallerPath
  # Start-Process -Wait 'msiexec' -ArgumentList "/i $nodeInstallerPath /quiet"
  # Remove-Item $nodeInstallerPath
  # # Refresh the path environment variable
  # $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine')
}

# Error if Yeoman and VS Code Extension generator are not found
$yo = Get-Command yo -ErrorAction SilentlyContinue
$generatecode = Get-Command yo code -ErrorAction SilentlyContinue
#  ToDo: figure out how to tell if generator-code has been installed
if (-not $yo -or -not $generatecode) {
  $message = 'yo or generator-code are not installed'
  Write-PSFMessage -Level Error -Message $message
  # toDo catch the errors, add to 'Problems'
  Throw $message
  # npm install -g yo generator-code
}

# Error if Typescript compiler is not found
$npx = Get-Command npx -ErrorAction SilentlyContinue
#  ToDo: figure out how to tell if Typescript compiler has been installed
if (-not $npx) {
  $message = 'npx is not installed'
  Write-PSFMessage -Level Error -Message $message
  # toDo catch the errors, add to 'Problems'
  Throw $message
  # npm install typescript --save-dev
}

# Generate the extension
$message = "Generating VSC Extension $extensionName --extensionType='ts' --extensionDescription= $extensionDescription - --installDependencies=true"
Write-PSFMessage -Level Debug -Message $message


#yo.ps1 code --extensionType='ts' --extensionName="$extensionName" --extensionDescription='$extensionDescription' --extensionPublisher='$extensionPublisher' --installDependencies=true" -NoNewWindow >$null
# Navigate to the extension folder
Set-Location  $extensionName

# Create folder structure and minimal files
Write-Host 'Creating folder structure and files...'
New-Item -ItemType 'directory' -Path '.\src'
New-Item -ItemType 'file' -Path '.\src\StringBuilder.ts'

# Create the StringBuilder class file content
$StringBuilderContent = @'
export default class StringBuilder {
    private _textArray: string[] = [];

    append(text: string): void {
        this._textArray.push(text);
    }

    toString(): string {
        return this._textArray.join('');
    }
}
'@

# Write the content to the file
Set-Content -Path '.\src\StringBuilder.ts' -Value $StringBuilderContent

# Add code to copy highlighted text to a StringBuilder object
$activateExtensionContent = @"
import * as vscode from 'vscode';
import StringBuilder from './StringBuilder';

export function activate(context: vscode.ExtensionContext) {

	let disposable = vscode.commands.registerCommand('$extensionName.copyToSubmit', () => {
		let editor = vscode.window.activeTextEditor;
		if (editor) {
			let document = editor.document;
			let selection = editor.selection;
			let text = document.getText(selection);

			let textToSubmit = new StringBuilder();
			textToSubmit.append(text);

			vscode.window.showInformationMessage('Text copied to textToSubmit StringBuilder object');
		}
	});

	context.subscriptions.push(disposable);
}
"@

# Update the extension.ts file with new content
Set-Content -Path '.\src\extension.ts' -Value $activateExtensionContent

# if the typescript package has not yer been added to this vscode project, do it now
# ToDo: determin how to detect if typescript package has been added to theproject
npm install typescript

# Compile TypeScript files
$message = "Compiling all Typescript files in $extensionName"
Write-PSFMessage -Level Debug -Message $message

npx tsc

$message = "Extension $extensionName has been created and set up."
Write-PSFMessage -Level Important -Message $message
