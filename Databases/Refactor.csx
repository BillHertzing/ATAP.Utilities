var pathToMyCSharpFile = @"C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.StronglyTypedIds.Interfaces\IStronglyTypedIds.cs";
var content = File.ReadAllText(pathToMyCSharpFile);
var editor = CreateEditor(content);

// string -> syntax tree
private SyntaxEditor CreateEditor(string content)
{
    var syntaxRoot = SyntaxFactory.ParseCompilationUnit(content);
    return new SyntaxEditor(syntaxRoot, new AdhocWorkspace());
}

// syntax tree -> string
private string FormatChanges(SyntaxNode node)
{
    var workspace = new AdhocWorkspace();
    var options = workspace.Options
        // change these values to fit your environment / preferences
        .WithChangedOption(FormattingOptions.UseTabs, LanguageNames.CSharp, value: true)
        .WithChangedOption(FormattingOptions.NewLine, LanguageNames.CSharp, value: "\r\n");
    return Formatter.Format(node, workspace, options).ToFullString();

}
