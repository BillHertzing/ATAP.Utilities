using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Localization;
using Microsoft.Extensions.Logging;

using ATAP.Utilities.ETW;
using ATAP.Utilities.GenerateProgram;
namespace ATAP.Services.HostedService.GenerateProgram {
  public interface IGenerateProgramHostedServiceData : IDisposable {

    IGAssemblyGroupSignil? GAssemblyGroupSignil { get; set; }
    IGGlobalSettingsSignil? GGlobalSettingsSignil { get; set; }
    IGSolutionSignil? GSolutionSignil { get; set; }
          // The following parameters are for each invocation of a GenerateProgramAsync call
      // invoking a GenerateProgram call may override any of these values, but absent an override, these are the
      //  default values that will be used for every GenerateProgramAsync call.
      //  the default values come from the ICOnfiguration hostedServiceConfiguration that is DI injected at service startup
      /// ToDo: Security: ensure the paths do not go above their Base directory
    IGGenerateProgramResult GGenerateProgramResult { get; set; }
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

    IEntryPoints EntryPoints {get;set;}

  }
}
