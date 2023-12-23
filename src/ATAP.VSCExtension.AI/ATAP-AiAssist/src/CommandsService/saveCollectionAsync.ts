import { LogLevel, ILogger } from '@Logger/index';
import { IData, IFileManager } from '@DataService/index';
import {} from '@DataService/index';
import { HandleError } from '@ErrorClasses/index';

export async function saveTagCollectionAsync(logger: ILogger, data: IData): Promise<void> {
  try {
    logger.log('starting function saveTagCollectionAsync', LogLevel.Debug);
    await data.fileManager.saveTagCollectionAsync();
    logger.log('finished function saveTagCollectionAsync', LogLevel.Debug);
  } catch (e) {
    HandleError(e, 'classless', 'saveTagCollectionAsync', `failed calling data.fileManager.saveTagCollectionAsync()`);
  }
}

export async function saveCategoryCollectionAsync(logger: ILogger, data: IData): Promise<void> {
  try {
    logger.log('starting function saveCategoryCollectionAsync', LogLevel.Debug);
    await data.fileManager.saveCategoryCollectionAsync();
    logger.log('finished function saveCategoryCollectionAsync', LogLevel.Debug);
  } catch (e) {
    HandleError(
      e,
      'classless',
      'saveCategoryCollectionAsync',
      `failed calling data.fileManager.saveCategoryCollectionAsync()`,
    );
  }
}

export async function saveAssociationCollectionAsync(logger: ILogger, data: IData): Promise<void> {
  try {
    logger.log('starting function saveAssociationCollectionAsync', LogLevel.Debug);
    await data.fileManager.saveAssociationCollectionAsync();
    logger.log('finished function saveAssociationCollectionAsync', LogLevel.Debug);
  } catch (e) {
    HandleError(
      e,
      'classless',
      'saveAssociationCollectionAsync',
      `failed calling data.fileManager.saveAssociationCollectionAsync()`,
    );
  }
}

export async function saveConversationCollectionAsync(logger: ILogger, data: IData): Promise<void> {
  try {
    logger.log('starting function saveConversationCollectionAsync', LogLevel.Debug);
    await data.fileManager.saveConversationCollectionAsync();
    logger.log('finished function saveConversationCollectionAsync', LogLevel.Debug);
  } catch (e) {
    HandleError(
      e,
      'classless',
      'saveConversationCollectionAsync',
      `failed calling data.fileManager.saveConversationCollectionAsync()`,
    );
  }
}
