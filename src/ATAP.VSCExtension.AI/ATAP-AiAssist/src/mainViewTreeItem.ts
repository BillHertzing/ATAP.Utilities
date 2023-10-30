
import * as vscode from 'vscode';

export class mainViewTreeItem extends vscode.TreeItem {
  public Philote_ID: string;
  public pickedValue: string;


  constructor(label: string, collapsibleState: vscode.TreeItemCollapsibleState,  public readonly properties: any) { //guid: string, pickedValue: string,  public properties: any
    super(label, collapsibleState);
    this.contextValue = 'myContent';
    this.Philote_ID = 'dummy';  //guid;
    this.pickedValue = 'dummy2';  //pickedValue;
  }
}


