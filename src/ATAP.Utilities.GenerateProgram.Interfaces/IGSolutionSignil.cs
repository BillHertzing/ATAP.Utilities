using System;
using System.Collections.Generic;

using ATAP.Utilities.StronglyTypedId;
namespace ATAP.Utilities.GenerateProgram {
  public interface IGSolutionSignilId<TValue> : IAbstractStronglyTypedId<TValue> where TValue : notnull { }
  public interface IGSolutionSignil<TValue> where TValue : notnull {
    public bool HasPropsAndTargets { get; }
    public bool HasEditorConfig { get; }
    public bool HasArtifacts { get; }
    public bool HasDevLog { get; }
    public bool HasDocumentation { get; }
    string SourceRelativePath { get; }
    string TestsRelativePath { get; }
    public bool HasOmniSharpConfiguration { get; }
    public bool HasVisualStudioCodeWorkspaceConfiguration { get; }
    public bool HasVisualStudioIISApplicationHostConfiguration { get; }
    public bool HasDataBases { get; }
    public ICollection<string> BuildConfigurations { get; }
    public ICollection<string> CPUConfigurations { get; }
    public IGPatternReplacement<TValue> GPatternReplacement { get; }
    public IDictionary<IGProjectUnitId<TValue>, IGProjectUnit<TValue>> GDependencyPackages { get; }
    public IDictionary<IGProjectUnitId<TValue>, IGProjectUnit<TValue>> GDependencyProjects { get; }
    public IGComment<TValue> GComment { get; }
    IGArgumentId<TValue> Id { get; init; }
  }
}



