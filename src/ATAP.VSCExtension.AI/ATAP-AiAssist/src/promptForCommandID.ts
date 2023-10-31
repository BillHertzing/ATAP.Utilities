import * as vscode from "vscode";

export async function promptForCommandID(): Promise<{
  success: boolean;
  inputCommandID: string | null;
  validatedCommandID: string | null;
  errorMessage: string | null;
}> {
  // Prompt the user for a commandID
  const inputCommandID = await vscode.window.showInputBox({
    prompt: "Enter a commandID",
    placeHolder: "removeRegion",
  });

  const allCommands = await vscode.commands.getCommands(true);
  // Check if the input was provided
  if (inputCommandID) {
    // Check if the provided input is in the list of allCommands
    if (allCommands.includes(inputCommandID)) {
      // validate
      return {
        success: true,
        inputCommandID: inputCommandID,
        validatedCommandID: inputCommandID,
        errorMessage: null,
      };
    } else {
      return {
        success: false,
        inputCommandID: inputCommandID,
        validatedCommandID: null,
        errorMessage: `${inputCommandID} is not a valid commandID`,
      };
    }
  } else {
    return {
      success: false,
      inputCommandID: null,
      validatedCommandID: null,
      errorMessage: "No command ID provided."
    };
  }
}
