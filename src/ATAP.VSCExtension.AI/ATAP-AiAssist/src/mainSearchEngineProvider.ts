// The necessary APIs are still in development, as #enable#enabledApiProposals.
// Following body of commented code are scaffolds for the ATAP implementation

// import * as vscode from 'vscode';

// export class mainSearchEngineProvider implements vscode.SearchProvider {
//     provideFileSearchResults(
//         query: vscode.TextSearchQuery,
//         options: vscode.TextSearchOptions,
//         progress: vscode.Progress<vscode.TextSearchResult>,
//         token: vscode.CancellationToken
//     ): vscode.ProviderResult<vscode.TextSearchComplete> {
//         // Implementation here
//         return new Promise(resolve => {
//             // ... search logic
//             // Report a result through the progress parameter
//             progress.report({uri: vscode.Uri.file('some/file'), ranges: [new vscode.Range(0, 0, 0, 10)]});
//             // Indicate that the search is complete
//             resolve({limitHit: false});
//         });
//     }
// }
