using System;
using ATAP.Utilities.ETW;
using ATAP.Utilities.Philote;
using ATAP.Utilities.Persistence;
using ATAP.Utilities.GenerateProgram;
namespace ATAP.Services.HostedService.GenerateProgram
{
  public interface IGInvokeGenerateCodeSignil {
        // The following parameters are for each invocation of a InvokeGenerateCode call
    // invoking a InvokeGenerateCode call may override any of these values, but absent an override, these are the
    //  default values that will be used for every GenerateProgramAsync call.
    //  the default values come from the ICOnfiguration hostedServiceConfiguration that is DI injected at service startup
    /// ToDo: Security: ensure the paths do not go above their Base directory
    IGAssemblyGroupSignil? GAssemblyGroupSignil { get; set; }
    IGGlobalSettingsSignil? GGlobalSettingsSignil { get; set; }
    IGSolutionSignil? GSolutionSignil { get; set; }
    string ArtifactsDirectoryBase { get; set; }
    string ArtifactsFileRelativePath { get; set; }
    string[] ArtifactsFilePaths { get; set; }
    bool EnablePersistence { get; set; }
    bool EnablePickAndSave { get; set; }
    bool EnableProgress { get; set; }
    string TemporaryDirectoryBase { get; set; }
    string PersistenceMessageFileRelativePath { get; set; }
    string[] PersistenceFilePaths { get; set; }
    string PickAndSaveMessageFileRelativePath { get; set; }
    string[] PickAndSaveFilePaths { get; set; }
    string DBConnectionString { get; set; }
    string OrmLiteDialectProviderStringDefault { get; set; }
    IEntryPoints EntryPoints { get; set; }
  }

}
