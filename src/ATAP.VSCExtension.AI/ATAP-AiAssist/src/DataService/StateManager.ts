import * as vscode from 'vscode';
import { LogLevel, ILogger, Logger } from '@Logger/index';

export interface IStateManager {
  getsavedPromptDocumentData(): string | undefined;
  setSavedPromptDocumentData(value: string): Promise<void>;
}

export class StateManager {
  private readonly cache: GlobalStateCache;
  constructor(
    private logger: ILogger,
    readonly extensionContext: vscode.ExtensionContext, //,
  ) // readonly folder: vscode.WorkspaceFolder,
  {
    this.cache = new GlobalStateCache(extensionContext);
  }

  getsavedPromptDocumentData(): string | undefined {
    return this.cache.getValue('replacementpattern');
  }

  async setSavedPromptDocumentData(value: string): Promise<void> {
    await this.cache.setValue<string>('replacementPattern', value);
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
    await this.extensionContext.globalState.update(key, value);
  }

  async clearValue(key: string): Promise<void> {
    // Clear the cache
    delete this.cache[key];

    // Remove the value from globalState
    await this.extensionContext.globalState.update(key, undefined);
  }
}
