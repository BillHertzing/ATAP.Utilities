# Creating Visual Studio Code extensions

Atribution:
[Your First Extension](https://code.visualstudio.com/api/get-started/your-first-extension)

## Installing Node.js

download executable from [Node.js downbload page](https://nodejs.org/en)

Scan for virus, unblock the security "came from the Internet attribute", then install from an elevted prompt.

- use default install location '"C:\Program Files\nodejs\"'

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
? What's the name of your extension? ATAP.AIAssist
? What's the identifier of your extension? atap-aiassist
? What's the description of your extension? Use Google voice recognition to send prompts to ChatGPT and copy the results
into a VSC Code editor.
? Initialize a git repository? No
? Bundle the source code with webpack? Yes
? Which package manager to use? npm

After creation, the following message appears:
To start editing with Visual Studio Code, use the following commands:

code atap-aiassist

Open vsc-extension-quickstart.md inside the new extension for further instructions
on how to modify, test and publish your extension.

To run the extension you need to install the recommended extension 'amodio.tsl-problem-matcher'.

? Do you want to open the new folder with Visual Studio Code? (Use arrow keys)

> Open with `code`

## Install global Node support packages

```Powershell
npm install -g npm-check-updates

```

## Install the VSC extension for Typescript

`amodio.tsl-problem-matcher`

## Install the node.js modules needed for the production package

The extension needs support for YAML and using a WebAPI. Run from a terminal at the base of the extension directory

```Powershell
npm install js-yaml
```

## Install the node.js modules for development

Run from a terminal, the base of the extension directory

```Powershell
npm install --save-dev  @types/vscode
npm install --save-dev @types/js-yaml

## needed to support paths in both extension development and extension testing
npm install --save-dev tsconfig-paths-webpack-plugin
npm install --save-dev tsconfig-paths
npm install --save-dev source-map-loader
## needed to use webpack to transpile and run tests
npm install --save-dev mocha @types/mocha
npm install --save-dev chai @types/chai
npm install path-browserify assert stream-browserify https-browserify os-browserify url --save-dev
# needed for support of paths in tests
npm install --save-dev ts-node
npm install --save-dev module-alias
# needed for mocking in tests
npm install --save-dev sinon @types/sinon
```

### updating all node packages

To update all of the packages in the project to their latest version

```Powershell
npm install -g npm-check-updates
cd <extension development project path>
ncu -u
npm install

```

## Install the VSC extension for linting JavaScript

`dbaeumer.vscode-eslint`

## initial compile and run

The generated scaffold has simplistic views of the VSC configuration files. You should delete them and install symbolic links to the cross-repository version-controlled files. More information is in the repository SharedVSCode 's readme file. [TBD](TBD)#ToDo: replace with static site URL

These files must be integrated into the repository-wide versions of the same files. Edit the following files located in `.vscode` directory under `ATAP.Utilities` repository root.

### launch.json

from the generated file, copy the contents of the `configurations:` section into the global file. Place it at the top of the file so the shortcut keys launch these tasks.

### tasks.json

from the generated file, copy the contents of the `tasks:` section into the global file. Place it at the top of the file so the shortcut keys launch these tasks.

### extensions.json

from the generated file, copy the contents of the `recommendations:` and add to the corresponding key in the global file.

The basic "hello World" VSC extension can now be compiled, packed, and run by pressing the `F5` key

Also see the file X in folder x

## Application specific

### chatGPT

```Powershell
npm install axios
npm install bluebird
npm install diff
npm install openai
npm install kdbxweb
npm install @types/axios --save-dev
npm install @types/bluebird --save-dev
npm install @types/diff --save-dev
npm install @types/kdbxweb --save-dev

```
