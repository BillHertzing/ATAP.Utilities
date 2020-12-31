using System;
using System.Collections.Generic;
using ATAP.Utilities.Philote;
namespace ATAP.Utilities.GenerateProgram {
  public interface IGSolutionSignil {
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
    public IGPatternReplacement GPatternReplacement { get; }
        public IDictionary<IPhilote<IGProjectUnit>, IGProjectUnit> GDependencyPackages { get;  }
    public IDictionary<IPhilote<IGProjectUnit>, IGProjectUnit> GDependencyProjects { get;  }

    public IGComment GComment { get; }

  }
}
