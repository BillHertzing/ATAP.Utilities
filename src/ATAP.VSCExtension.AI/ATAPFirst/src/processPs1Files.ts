import * as vscode from 'vscode';
import * as fs from 'fs';
import * as path from 'path';

export async function processPs1Files(commandId: string): Promise<void> {
    // Ensure a workspace is open
    if (!vscode.workspace.workspaceFolders) {
        vscode.window.showErrorMessage('No workspace is open.');
        return;
    }

    // Initialize the files array
    let ps1Files: string[] = [];

    // Loop through each workspace folder
    for (const folder of vscode.workspace.workspaceFolders) {
        const folderPath = folder.uri.fsPath;

        // Find and store all .ps1 files in the workspace recursively
        findPs1Files(folderPath, ps1Files);
    }

    // Process each .ps1 file
    for (const ps1File of ps1Files) {
        const fileUri = vscode.Uri.file(ps1File);

        // Apply the command to the file
        // await vscode.commands.executeCommand(commandId, fileUri);
        vscode.window.showInformationMessage(
          "commandId ${commandId} applied to file ${fileUri}"
        );
    }

    vscode.window.showInformationMessage(`Processed ${ps1Files.length} .ps1 files.`);
}

function findPs1Files(dir: string, fileList: string[]) {
    const files = fs.readdirSync(dir);
    for (const file of files) {
        const filePath = path.join(dir, file);
        if (fs.statSync(filePath).isDirectory()) {
            findPs1Files(filePath, fileList);
        } else if (path.extname(file) === '.ps1') {
            fileList.push(filePath);
        }
    }
}
