import * as vscode from "vscode";
import * as fs from "fs";
import * as path from "path";
import { promptForCommandID } from "./promptForCommandID";

export async function processPs1Files(commandId: string | null): Promise<{
  success: boolean;
  commandIDUsed: string | null;
  numFilesProcessed: number | null;
  errorMessage: string | null;
}> {
  let message: string = "";

  if (commandId === null) {
    (async () => {
      const commandIDFromPromptRecord = await promptForCommandID();

      if (commandIDFromPromptRecord.success) {
        commandId = commandIDFromPromptRecord.validatedCommandID;
        return {
          success: true,
          commandIDUsed: null,
          numFilesProcessed: null,
          errorMessage: message,
        };
      } else {
        message = `Prompting the user for a commandID returned the following error: ${commandIDFromPromptRecord.errorMessage}`;
        return {
          success: false,
          commandIDUsed: null,
          numFilesProcessed: null,
          errorMessage: message,
        };
      }
    })();
  }

  // Ensure a workspace is open
  if (!vscode.workspace.workspaceFolders) {
    return {
      success: false,
      commandIDUsed: null,
      numFilesProcessed: null,
      errorMessage: "No workspace is open.",
    };
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
      `commandId ${commandId} applied to file ${fileUri}`
    );
  }
  return {
    success: true,
    commandIDUsed: commandId,
    numFilesProcessed: ps1Files.length,
    errorMessage: null,
  };
}

function findPs1Files(dir: string, fileList: string[]) {
  const files = fs.readdirSync(dir);
  for (const file of files) {
    const filePath = path.join(dir, file);
    if (fs.statSync(filePath).isDirectory()) {
      findPs1Files(filePath, fileList);
    } else if (path.extname(file) === ".ps1") {
      fileList.push(filePath);
    }
  }
}
