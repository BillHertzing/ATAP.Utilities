
// The necessary APIs are still in development, as #enable#enabledApiProposals.
// Following body of commented code are scaffolds for the ATAP implementation

// import * as vscode from 'vscode';

// async function searchText() {
//     const query: vscode.TextSearchQuery = {
//         pattern: 'TODO',  // The text you're searching for
//         isCaseSensitive: false
//     };

//     const options: vscode.TextSearchOptions = {
//         maxResults: 100,
//         includes: ['*.ts', '*.js'],
//         excludes: ['node_modules/**'],
//         useIgnoreFiles: true,
//         useGlobalIgnoreFiles: true
//     };

//     const tokenSource = new vscode.CancellationTokenSource();
//     const progressOptions: vscode.ProgressOptions = { location: vscode.ProgressLocation.Notification, title: 'Searching...' };

//     vscode.window.withProgress(progressOptions, async (progress) => {
//         return vscode.workspace.findTextInFiles(query, options, result => {
//             progress.report({ message: `Found TODO at ${result.uri.fsPath}` });
//         }, tokenSource.token).then(complete => {
//             if (complete.limitHit) {
//                 vscode.window.showInformationMessage('Search limit hit!');
//             }
//         });
//     });
// }

// export function activate(context: vscode.ExtensionContext) {
//     let disposable = vscode.commands.registerCommand('extension.searchText', searchText);
//     context.subscriptions.push(disposable);
// }
