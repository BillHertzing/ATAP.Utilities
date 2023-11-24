import * as vscode from 'vscode';
import { LogLevel, ILogger, Logger } from '@Logger/index';
import { DetailedError } from '@ErrorClasses/index';

export interface IStateManager {
  getsavedPromptDocumentData(): string | undefined;
  setSavedPromptDocumentData(value: string): Promise<void>;
  getWorkspacePath(): string | undefined;
  setWorkspacePath(value: string): Promise<void>;
  getWorkspaceName(): string | undefined;
  setWorkspaceName(value: string): Promise<void>;
  getWorkspaceRootFolderPath(): string | undefined;
  setWorkspaceRootFolderPath(value: string): Promise<void>;
}

export class StateManager {
  private readonly cache: GlobalStateCache;
  constructor(
    private logger: ILogger,
    readonly extensionContext: vscode.ExtensionContext, //, // readonly folder: vscode.WorkspaceFolder,
  ) {
    this.cache = new GlobalStateCache(extensionContext);
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
