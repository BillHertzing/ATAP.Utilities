using System.Collections.Generic;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {

  public record GCompilationUnitId<TValue> : AbstractStronglyTypedId<TValue>, IGCompilationUnitId<TValue> where TValue : notnull {}
  public record GCompilationUnit<TValue> : IGCompilationUnit<TValue> where TValue : notnull {
    public GCompilationUnit(string gName = default, string gRelativePath = default, string gFileSuffix = default, Dictionary<IGUsingId<TValue>, IGUsing<TValue>> gUsings = default,
      Dictionary<IGUsingGroupId<TValue>, IGUsingGroup<TValue>> gUsingGroups = default,
      Dictionary<IGNamespaceId<TValue>, IGNamespace<TValue>> gNamespaces = default,
      IGPatternReplacement gPatternReplacement = default,
    IGComment gComment = default
      ) {
      GName = gName == default ? "" : gName;
      GRelativePath = gRelativePath == default ? "" : gRelativePath;
      GFileSuffix = gFileSuffix == default ? ".cs" : gFileSuffix;
      GUsings = gUsings == default ? new Dictionary<IGUsingId<TValue>, IGUsing<TValue>>() : gUsings;
      GUsingGroups = gUsingGroups == default ? new Dictionary<IGUsingGroupId<TValue>, IGUsingGroup<TValue>>() : gUsingGroups;
      GNamespaces = gNamespaces == default ? new Dictionary<IGNamespaceId<TValue>, IGNamespace<TValue>>() : gNamespaces;
      GPatternReplacement = gPatternReplacement == default ? new GPatternReplacement() : gPatternReplacement;
      GComment = gComment == default ? new GComment() : gComment;
      Id = new GCompilationUnitId<TValue>();
    }

    public string GName { get; init; }
    public Dictionary<IGUsingGroupId<TValue>, IGUsingGroup<TValue>> GUsingGroups { get; init; }
    public Dictionary<IGUsingId<TValue>, IGUsing<TValue>> GUsings { get; init; }
    public Dictionary<IGNamespaceId<TValue>, IGNamespace<TValue>> GNamespaces { get; init; }
    public string GRelativePath { get; init; }
    public string GFileSuffix { get; init; }
    public IGPatternReplacement GPatternReplacement { get; init; }
    public IGComment GComment { get; init; }
    public  IGCompilationUnitId Id { get; init; }
    public static string Header { get; } = "// " + StringConstants.AutoGeneratedHeaderCommentTextStringDefault;
  }
}








