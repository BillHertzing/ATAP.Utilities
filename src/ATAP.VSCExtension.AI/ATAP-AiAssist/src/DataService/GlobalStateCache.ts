import * as vscode from 'vscode';

export class GlobalStateCache {
    private cache: { [key: string]: any } = {};
    private extensionContext: vscode.ExtensionContext;

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

// Usage
    // Set a value
    // globalStateCache.setValue('myKey', 'myValue');

    // Get a value
    // myValue = globalStateCache.getValue<string>('myKey');
