import { LogLevel, ILogger } from '../Logger';
import * as vscode from 'vscode';

// Import the interface and class for Category and Categorys
import { Philote, GUID, Int, IDType, Category, Categorys } from '../PredicatesService';

export async function quickPickFromSettings(
  logger: ILogger,
  setting: string,
): Promise<{
  success: boolean;
  pick: string | null;
  errorMessage: string | null;
}> {
  let message: string = `starting commandID quickPickFromSettings, setting is ${setting}`;
  logger.log(message, LogLevel.Debug);

  // Retrieve the latest settings directly within the command to ensure the most current values
  const config = vscode.workspace.getConfiguration('ATAP-AiAssist');
  const settingStr: string | undefined = config.get(setting);
  if (!settingStr || settingStr.length === 0) {
    message = `No string found in atap-aiassist ${setting}`;
    logger.log(message, LogLevel.Error);
    return {
      success: false,
      pick: null,
      errorMessage: message,
    };
  }

  const categorys = Categorys.convertFrom_json<GUID>(settingStr);
  if (!categorys.categories || categorys.categories.length === 0) {
    message = `Could not convert to a Categorys instance from atap-aiassist ${setting} : ${settingStr}`;
    logger.log(message, LogLevel.Error);
    return {
      success: false,
      pick: null,
      errorMessage: message,
    };
  }

  categorys.categories.map((object) => object.name);
  const optionsArray: string[] = categorys.categories.map((object) => object.name);
  if (!optionsArray || optionsArray.length === 0) {
    message = `Could not convert the categorys.categories to an optionsArray of strings`;
    logger.log(message, LogLevel.Error);
    return {
      success: false,
      pick: null,
      errorMessage: message,
    };
  }

  // Show QuickPick with the options from settings
  const pick = await vscode.window.showQuickPick(optionsArray, {
    placeHolder: 'Select an option',
  });

  if (pick !== undefined) {
    // ToDo:pick is just the name, get the entire Category instance
    const pickedCategory = categorys.findByName<GUID>(pick);
    return {
      success: true,
      pick: pick,
      errorMessage: null,
    };
  } else {
    message = 'Quick Pick was canceled';
    return {
      success: false,
      pick: null,
      errorMessage: message,
    };
  }
}
