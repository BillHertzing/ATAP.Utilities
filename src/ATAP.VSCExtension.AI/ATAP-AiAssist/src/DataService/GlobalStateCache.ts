import * as vscode from 'vscode';

export class GlobalStateCache {
    private cache: { [key: string]: any } = {};
    private context: vscode.ExtensionContext;

    constructor(context: vscode.ExtensionContext) {
        this.context = context;
    }

    getValue<T>(key: string): T | undefined {
        // First, try to get the value from the in-memory cache
        if (this.cache.hasOwnProperty(key)) {
            return this.cache[key] as T;
        }

        // If not available, read from globalState and update the cache
        const value = this.context.globalState.get<T>(key);
        if (value !== undefined) {
            this.cache[key] = value;
        }
        return value;
    }

    async setValue<T>(key: string, value: T): Promise<void> {
        // Update the cache first
        this.cache[key] = value;

        // Persist the value to globalState
        await this.context.globalState.update(key, value);
    }

    async clearValue(key: string): Promise<void> {
        // Clear the cache
        delete this.cache[key];

        // Remove the value from globalState
        await this.context.globalState.update(key, undefined);
    }
}

// Usage
export function activate(context: vscode.ExtensionContext) {
    const globalStateCache = new GlobalStateCache(context);

    // Set a value
    globalStateCache.setValue('myKey', 'myValue');

    // Get a value
    const myValue = globalStateCache.getValue<string>('myKey');
    console.log(myValue); // 'myValue' or undefined
}

export function deactivate() {}