import { LogLevel, ILogger } from '../Logger';
import { GUID, Int, IDType, } from '@IDTypes/IDTypes';
import { IItem, Item, IItemCollection, ItemCollection } from '@PredicatesService/PredicatesService';
import { ICategory, Category, ICategoryCollection,CategoryCollection } from '@PredicatesService/PredicatesService';
import { ITag, Tag, ITagCollection,TagCollection } from '@PredicatesService/PredicatesService';

import * as vscode from 'vscode';

export async function quickPickFromSettings<T extends IDType>(
  logger: ILogger,
  setting: string,
): Promise<{
  success: boolean;
  pick: IItemCollection<T> | null;
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

  const categorycollection = CategoryCollection.convertFrom_json<T>(settingStr);
  if (!categorycollection.items || categorycollection.items.length === 0) {
    message = `Could not convert to a CategoryCollection instance from atap-aiassist ${setting} : ${settingStr}`;
    logger.log(message, LogLevel.Error);
    return {
      success: false,
      pick: null,
      errorMessage: message,
    };
  }

  categorycollection.items.map((object) => object.name);
  const optionsArray: string[] = categorycollection.items.map((object) => object.name);
  if (!optionsArray || optionsArray.length === 0) {
    message = `Could not convert the categorycollection.items to an optionsArray of strings`;
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
    const pickedCategory = categorycollection.findItemByName(pick);
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
