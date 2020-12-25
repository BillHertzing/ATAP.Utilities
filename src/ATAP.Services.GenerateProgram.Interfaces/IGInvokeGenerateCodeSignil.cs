using System;
using ATAP.Utilities.ETW;
using ATAP.Utilities.Philote;
using ATAP.Utilities.Persistence;
using ATAP.Utilities.GenerateProgram;
namespace ATAP.Services.HostedService.GenerateProgram
{
  public interface IGInvokeGenerateCodeSignil : IGGenerateCodeSignil {
    string PersistenceMessageFileRelativePath { get; set; }
    string[] PersistenceFilePaths { get; set; }
    string PickAndSaveMessageFileRelativePath { get; set; }
    string[] PickAndSaveFilePaths { get; set; }
    string DBConnectionString { get; set; }
    string OrmLiteDialectProviderStringDefault { get; set; }
    new IPhilote<IGInvokeGenerateCodeSignil> Philote {get; init;}
  }

}
