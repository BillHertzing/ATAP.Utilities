namespace ATAP.Utilities.RRSBS.Domain;

public enum RuleLanguage
{
    CSharp,
    PowerShell,
    Sql,
    MSBuild,
    Snippet,
    Path
}

public sealed record RuleDefinition(
    Guid Id,
    string Name,
    RuleLanguage Language,
    string? Purpose,
    IReadOnlyList<RuleStep> Steps);

public sealed record RuleStep(
    int Sequence,
    string PrimitiveName,
    IReadOnlyDictionary<string, string?> Inputs);
