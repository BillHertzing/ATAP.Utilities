
Atribution:
[Your First Extension](https://code.visualstudio.com/api/get-started/your-first-extension)

## Installing Node.js

download executable from [Node.js downbload page](https://nodejs.org/en)

Scan for virus, unblock the security "came from the Internet attribute",  then install from an elevted prompt.

+ use default install location '"C:\Program Files\nodejs\"'

The installation wants to install npm for the package manager, but nvs will 'integrate with VSC'. I am going to take the default npm for the first attempt at installation.

do NOT check the box for Node.js to install Python, MS Build tools, and chocolatey, as they should already be installed and in the path.

## Git

Git should already be installed

## Install Yeoman and VS Code Extension Generator

[Yeoman](https://yeoman.io/)

[VS Code Extension Generator, AKA Yo Code - Extension and Customization Generator ](https://www.npmjs.com/package/generator-code)

'npm install -g yo generator-code'

## Run the generator to build the extension

`yo code`

Answer as follows:
 What type of extension do you want to create? New Extension (TypeScript)
? What's the name of your extension? ATAP.ChatGPTAssistant
? What's the identifier of your extension? atap-chatgptassistant
? What's the description of your extension? Use Google voice recognition to send prompts to ChatGPT and copy the results
 into a VSC Code editor.
? Initialize a git repository? No
? Bundle the source code with webpack? Yes
? Which package manager to use? npm

After creation, the following message appears:
To start editing with Visual Studio Code, use the following commands:

     code atap-chatgptassistant

Open vsc-extension-quickstart.md inside the new extension for further instructions
on how to modify, test and publish your extension.

To run the extension you need to install the recommended extension 'amodio.tsl-problem-matcher'.

For more information, also visit http://code.visualstudio.com and follow us @code.


? Do you want to open the new folder with Visual Studio Code? (Use arrow keys)
> Open with `code`

## Install the VSC extension for Typescript

`amodio.tsl-problem-matcher`

## Install the VSC extension for linting JavaScript?

`dbaeumer.vscode-eslint`

## initial compile and run

The generated scaffold has simplistic views of the VSC configuration files. These files must be integrated into the repository-wide versions of the same files. Edit the follwoing files located in `.vscode` directory under `ATAP.Utilities` repository root.

### launch.json

from the generated file, copy the contents of the `configurations:` section into the global file. Place it at the top of the file so the shortcut keys launch these tasks.

### tasks.json

from the generated file, copy the contents of the `tasks:` section into the global file. Place it at the top of the file so the shortcut keys launch these tasks.

### extensions.json

from the generated file, copy the contents of the `recommendations:` and add to the corresponding key in the global file.

The basic "hello World" VSC extension can now be compiled, packed, and run by pressing the `F5` key

