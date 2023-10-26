import * as vscode from "vscode";

export async function promptForCommandID(): Promise<{
  success: boolean;
  validatedCommandID: string | null;
}> {
  const commandIDInput = await vscode.window.showInputBox({
    prompt: "Enter a commandID",
    placeHolder: "removeRegion",
  });

  const allCommands = await vscode.commands.getCommands(true);
  if (commandIDInput) {
    // Check if the input was provided
    if (allCommands.includes(commandIDInput)) {
      // validate
      return { success: true, validatedCommandID: commandIDInput };
    } else {
      vscode.window.showErrorMessage(
        `${commandIDInput} is not a valid commandID`
      );
      return { success: false, validatedCommandID: null };
    }
  } else {
    vscode.window.showErrorMessage("No command ID provided.");
    return { success: false, validatedCommandID: null };
  }
}
