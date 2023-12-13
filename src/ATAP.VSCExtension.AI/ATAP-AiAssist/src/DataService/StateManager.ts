import * as vscode from 'vscode';
import { LogLevel, ILogger, Logger } from '@Logger/index';
import { DetailedError } from '@ErrorClasses/index';

import {
  ItemWithIDValueType,
  ItemWithIDTypes,
  MapTypeToValueType,
  YamlData,
  fromYamlForItemWithID,
  IItemWithID,
  ItemWithID,
  ICollection,
  Collection,
  IFactory,
  Factory,
  ICollectionFactory,
  CollectionFactory,
  TagValueType,
  ITag,
  Tag,
  ITagCollection,
  TagCollection,
  CategoryValueType,
  ICategory,
  Category,
  ICategoryCollection,
  CategoryCollection,
  TokenValueType,
  IToken,
  Token,
  ITokenCollection,
  TokenCollection,
  AssociationValueType,
  IAssociation,
  Association,
  IAssociationCollection,
  AssociationCollection,
  QueryContextValueType,
  IQueryContext,
  QueryContext,
  IQueryContextCollection,
  QueryContextCollection,
  // ConversationValueType,
  // IConversation,
  // Conversation,
  // IConversationCollection,
  // ConversationCollection,
} from '@ItemWithIDs/index';
import { log } from 'console';

export interface IStateManager {
  getsavedPromptDocumentData(): string | undefined;
  setSavedPromptDocumentData(value: string): Promise<void>;
  getWorkspacePath(): string | undefined;
  setWorkspacePath(value: string): Promise<void>;
  getWorkspaceName(): string | undefined;
  setWorkspaceName(value: string): Promise<void>;
  getWorkspaceRootFolderPath(): string | undefined;
  setWorkspaceRootFolderPath(value: string): Promise<void>;
  getCurrentTag(): ITag | undefined;
  setCurrentTag(value: ITag): Promise<void>;
  getTagCollection(): ITagCollection | undefined;
  setTagCollection(value: ITagCollection): Promise<void>;
  getCurrentCategory(): ICategory | undefined;
  setCurrentCategory(value: ICategory): Promise<void>;
  getCategoryCollection(): ICategoryCollection | undefined;
  setCategoryCollection(value: ICategoryCollection): Promise<void>;
  getCurrentAssociation(): IAssociation | undefined;
  setCurrentAssociation(value: IAssociation): Promise<void>;
  getAssociationCollection(): IAssociationCollection | undefined;
  setAssociationCollection(value: IAssociationCollection): Promise<void>;
  getCurrentQueryContext(): IQueryContext | undefined;
  setCurrentQueryContext(value: IQueryContext): Promise<void>;
  getQueryContextCollection(): IQueryContextCollection | undefined;
  setQueryContextCollection(value: IQueryContextCollection): Promise<void>;
  // getCurrentConversation(): IConversation | undefined;
  // setCurrentConversation(value: IConversation): Promise<void>;
  // getConversationCollection(): IConversationCollection | undefined;
  // setConversationCollection(value: IConversationCollection): Promise<void>;
}

export class StateManager {
  private readonly cache: GlobalStateCache;
  constructor(
    private logger: ILogger,
    readonly extensionContext: vscode.ExtensionContext, //, // readonly folder: vscode.WorkspaceFolder,
  ) {
    this.cache = new GlobalStateCache(extensionContext);
    // create new collections if there is no collection in GlobalState
    if (!this.cache.getValue<TagCollection>('TagCollection')) {
      // Immediately Invoked Async Function Expression (IIFE)
      (() => {
        this.cache.setValue<TagCollection>('TagCollection', new TagCollection([])).catch((e) => {
          if (e instanceof Error) {
            throw new DetailedError(`StateManager.constructor: failed to set TagCollection -> `, e);
          } else {
            throw new Error(
              `StateManager .ctor: failed to set TagCollection and the instance of (e) returned is of type ${typeof e}`,
            );
          }
        });
      })();
      // ToDo: possibly add validationthat the new collection was created
    }
    if (!this.cache.getValue<CategoryCollection>('CategoryCollection')) {
      // Immediately Invoked Async Function Expression (IIFE)
      (() => {
        this.cache.setValue<CategoryCollection>('CategoryCollection', new CategoryCollection([])).catch((e) => {
          if (e instanceof Error) {
            throw new DetailedError(`StateManager.constructor: failed to set CategoryCollection -> `, e);
          } else {
            throw new Error(
              `StateManager .ctor: failed to set CategoryCollection and the instance of (e) returned is of type ${typeof e}`,
            );
          }
        });
      })();
      // ToDo: possibly add validationthat the new collection was created
    }
    if (!this.cache.getValue<AssociationCollection>('AssociationCollection')) {
      // Immediately Invoked Async Function Expression (IIFE)
      (() => {
        this.cache
          .setValue<AssociationCollection>('AssociationCollection', new AssociationCollection([]))
          .catch((e) => {
            if (e instanceof Error) {
              throw new DetailedError(`StateManager.constructor: failed to set AssociationCollection -> `, e);
            } else {
              throw new Error(
                `StateManager .ctor: failed to set AssociationCollection and the instance of (e) returned is of type ${typeof e}`,
              );
            }
          });
      })();
    }
    // ToDo: possibly add validationthat the new collection was created
    if (!this.cache.getValue<QueryContextCollection>('QueryContextCollection')) {
      // Immediately Invoked Async Function Expression (IIFE)
      (() => {
        this.cache
          .setValue<QueryContextCollection>('QueryContextCollection', new QueryContextCollection([]))
          .catch((e) => {
            if (e instanceof Error) {
              throw new DetailedError(`StateManager.constructor: failed to set QueryContextCollection -> `, e);
            } else {
              throw new Error(
                `StateManager .ctor: failed to set QueryContextCollection and the instance of (e) returned is of type ${typeof e}`,
              );
            }
          });
      })();
      // ToDo: possibly add validationthat the new collection was created
    }
    // if (!this.cache.getValue<ConversationCollection>('ConversationCollection')) {
    //   // Immediately Invoked Async Function Expression (IIFE)
    //   (() => {
    //     this.cache
    //       .setValue<ConversationCollection>('ConversationCollection', new ConversationCollection([]))
    //       .catch((e) => {
    //         if (e instanceof Error) {
    //           throw new DetailedError(`StateManager.constructor: failed to set ConversationCollection -> `, e);
    //         } else {
    //           throw new Error(
    //             `StateManager .ctor: failed to set ConversationCollection and the instance of (e) returned is of type ${typeof e}`,
    //           );
    //         }
    //       });
    //   })();
    //   // ToDo: possibly add validationthat the new collection was created
    // }
  }

  getsavedPromptDocumentData(): string | undefined {
    return this.cache.getValue('savedPromptDocumentData');
  }

  async setSavedPromptDocumentData(value: string): Promise<void> {
    await this.cache.setValue<string>('savedPromptDocumentData', value);
  }

  getWorkspacePath(): string | undefined {
    return this.cache.getValue('WorkspacePath');
  }

  async setWorkspacePath(value: string): Promise<void> {
    await this.cache.setValue<string>('WorkspacePath', value);
  }

  getWorkspaceName(): string | undefined {
    return this.cache.getValue('WorkspaceName');
  }

  async setWorkspaceName(value: string): Promise<void> {
    await this.cache.setValue<string>('WorkspaceName', value);
  }

  getWorkspaceRootFolderPath(): string | undefined {
    return this.cache.getValue('WorkspaceRootFolderPath');
  }

  async setWorkspaceRootFolderPath(value: string): Promise<void> {
    await this.cache.setValue<string>('WorkspaceRootFolderPath', value);
  }

  getCurrentTag(): ITag | undefined {
    return this.cache.getValue<ITag>('Tag');
  }

  async setCurrentTag(value: ITag): Promise<void> {
    await this.cache.setValue<ITag>('Tag', value);
  }

  getTagCollection(): ITagCollection | undefined {
    return this.cache.getValue<ITagCollection>('TagCollection');
  }

  async setTagCollection(value: ITagCollection): Promise<void> {
    await this.cache.setValue<ITagCollection>('TagCollection', value);
  }

  getCurrentCategory(): ICategory | undefined {
    return this.cache.getValue<ICategory>('Category');
  }

  async setCurrentCategory(value: ICategory): Promise<void> {
    await this.cache.setValue<ICategory>('Category', value);
  }

  getCategoryCollection(): ICategoryCollection | undefined {
    return this.cache.getValue<ICategoryCollection>('CategoryCollection');
  }

  async setCategoryCollection(value: ICategoryCollection): Promise<void> {
    await this.cache.setValue<ICategoryCollection>('CategoryCollection', value);
  }

  getCurrentAssociation(): IAssociation | undefined {
    return this.cache.getValue<IAssociation>('Association');
  }

  async setCurrentAssociation(value: IAssociation): Promise<void> {
    await this.cache.setValue<IAssociation>('Association', value);
  }

  getAssociationCollection(): IAssociationCollection | undefined {
    return this.cache.getValue<IAssociationCollection>('AssociationCollection');
  }

  async setAssociationCollection(value: IAssociationCollection): Promise<void> {
    await this.cache.setValue<IAssociationCollection>('AssociationCollection', value);
  }

  getCurrentQueryContext(): IQueryContext | undefined {
    return this.cache.getValue<IQueryContext>('QueryContext');
  }

  async setCurrentQueryContext(value: IQueryContext): Promise<void> {
    await this.cache.setValue<IQueryContext>('QueryContext', value);
  }

  getQueryContextCollection(): IQueryContextCollection | undefined {
    return this.cache.getValue<IQueryContextCollection>('QueryContextCollection');
  }

  async setQueryContextCollection(value: IQueryContextCollection): Promise<void> {
    await this.cache.setValue<IQueryContextCollection>('QueryContextCollection', value);
  }
  // getCurrentConversation(): IConversation | undefined {
  //   return this.cache.getValue<IConversation>('Conversation');
  // }

  // async setCurrentConversation(value: IConversation): Promise<void> {
  //   await this.cache.setValue<IConversation>('Conversation', value);
  // }

  // getConversationCollection(): IConversationCollection | undefined {
  //   return this.cache.getValue<IConversationCollection>('ConversationCollection');
  // }

  // async setConversationCollection(value: IConversationCollection): Promise<void> {
  //   await this.cache.setValue<IConversationCollection>('ConversationCollection', value);
  // }
}

class GlobalStateCache {
  private readonly cache: { [key: string]: any } = {};
  private readonly extensionContext: vscode.ExtensionContext;

  constructor(extensionContext: vscode.ExtensionContext) {
    this.extensionContext = extensionContext;
  }

  getValue<T>(key: string): T | undefined {
    // First, try to get the value from the in-memory cache
    if (this.cache.hasOwnProperty(key)) {
      return this.cache[key] as T;
    }
    // If not available, read from globalState and update the cache
    const value = this.extensionContext.globalState.get<T>(key);
    if (value !== undefined) {
      this.cache[key] = value;
    }
    return value;
  }

  async setValue<T>(key: string, value: T): Promise<void> {
    // Update the cache first
    this.cache[key] = value;

    // Persist the value to globalState
    try {
      await this.extensionContext.globalState.update(key, value);
    } catch (e) {
      if (e instanceof Error) {
        throw new DetailedError(`GlobalStateCache: failed to set ${key} -> `, e);
      } else {
        // ToDo:  investigation to determine what else might happen
        throw new Error(
          `GlobalStateCache: failed to set ${key} and the instance of (e) returned is of type ${typeof e}`,
        );
      }
    }
  }

  async clearValue(key: string): Promise<void> {
    // Clear the cache
    delete this.cache[key];
    // Remove the value from globalState
    try {
      this.extensionContext.globalState.update(key, undefined);
    } catch (e) {
      if (e instanceof Error) {
        throw new DetailedError(`GlobalStateCache: failed to clear ${key} -> `, e);
      } else {
        // ToDo:  investigation to determine what else might happen
        throw new Error(
          `GlobalStateCache: failed to clear ${key} and the instance of (e) returned is of type ${typeof e}`,
        );
      }
    }
  }
}
