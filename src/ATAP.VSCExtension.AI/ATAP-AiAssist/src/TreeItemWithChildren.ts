import * as vscode from 'vscode';

export class TreeItemWithChildren extends vscode.TreeItem {
    children: TreeItemWithChildren[] | undefined;

    constructor(
        label: string,
        collapsibleState: vscode.TreeItemCollapsibleState,
        children?: TreeItemWithChildren[]
    ) {
        super(label, collapsibleState);
        this.children = children;
    }
}
