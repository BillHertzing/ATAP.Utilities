using System;
using System.Threading;

using ATAP.Utilities.Persistence;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {
  

  public interface IGGenerateCodeSignilId<TValue> : IAbstractStronglyTypedId<TValue> where TValue : notnull {}
  public interface IGGenerateCodeSignil<TValue> where TValue : notnull {
    IGAssemblyGroupSignil? GAssemblyGroupSignil { get; set; }
    //IGGlobalSettingsSignil? GGlobalSettingsSignil { get; set; }
    IGSolutionSignil? GSolutionSignil { get; set; }
    string ArtifactsDirectoryBase { get; set; }
    string ArtifactsFileRelativePath { get; set; }
    string[] ArtifactsFilePaths { get; set; }
    string TemporaryDirectoryBase { get; set; }
    bool EnableProgress { get; set; }
    bool EnablePersistence { get; set; }
    bool EnablePickAndSave { get; set; }
    IGGenerateCodeProgress? Progress { get; set; }
    IPersistence<IInsertResultsAbstract>? Persistence { get; set; }
    IPickAndSave<IInsertResultsAbstract>? PickAndSave { get; set; }
    IEntryPoints EntryPoints { get; set; }
     CancellationToken CancellationTokenFromCaller { get; set; }
    IGGenerateCodeSignilId<TValue> Id { get; init; }
  }

}


