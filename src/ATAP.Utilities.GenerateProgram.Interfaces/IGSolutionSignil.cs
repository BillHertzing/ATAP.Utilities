using System;
using System.Collections.Generic;

using ATAP.Utilities.StronglyTypedId;
namespace ATAP.Utilities.GenerateProgram {
  public interface IGSolutionSignilId<TValue> : IAbstractStronglyTypedId<TValue> where TValue : notnull { }
  public interface IGSolutionSignil<TValue> where TValue : notnull {
    bool HasPropsAndTargets { get; init; }
    bool HasEditorConfig { get; init; }
    bool HasArtifacts { get; init; }
    bool HasDevLog { get; init; }
    bool HasDocumentation { get; init; }
    string SourceRelativePath { get; init; }
    string TestsRelativePath { get; init; }
    bool HasOmniSharpConfiguration { get; init; }
    bool HasVisualStudioCodeWorkspaceConfiguration { get; init; }
    bool HasVisualStudioIISApplicationHostConfiguration { get; init; }
    bool HasDataBases { get; init; }
    ICollection<string> BuildConfigurations { get; init; }
    ICollection<string> CPUConfigurations { get; init; }
    IGPatternReplacement<TValue>? GPatternReplacement { get; init; }
    IDictionary<IGProjectUnitId<TValue>, IGProjectUnit<TValue>>? GDependencyPackages { get; init; }
    IDictionary<IGProjectUnitId<TValue>, IGProjectUnit<TValue>>? GDependencyProjects { get; init; }
    IGComment<TValue>? GComment { get; init; }
    IGSolutionSignilId<TValue> Id { get; init; }
  }
}



