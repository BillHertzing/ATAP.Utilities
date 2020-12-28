using System;
using System.Collections.Generic;
using ATAP.Utilities.Philote;
namespace ATAP.Utilities.GenerateProgram {
  public interface IGSolutionSignil {
    public bool HasPropsAndTargets { get; init; }
    public bool HasEditorConfig { get; init; }
    public bool HasArtifacts { get; init; }
    public bool HasDevLog { get; init; }
    public bool HasDocumentation { get; init; }
    string SourceRelativePath { get; init; }
    string TestsRelativePath { get; init; }
    public bool HasOmniSharpConfiguration { get; init; }
    public bool HasVisualStudioCodeWorkspaceConfiguration { get; init; }
    public bool HasVisualStudioIISApplicationHostConfiguration { get; init; }
    public bool HasDataBases { get; init; }
    public ICollection<string> BuildConfigurations { get; init; }
    public ICollection<string> CPUConfigurations { get; init; }
    public IGPatternReplacement GPatternReplacement { get; init; }
        public IDictionary<IPhilote<IGProjectUnit>, IGProjectUnit> GDependencyPackages { get;  init; }
    public IDictionary<IPhilote<IGProjectUnit>, IGProjectUnit> GDependencyProjects { get;  init; }

    public IGComment GComment { get; init; }

  }
}
