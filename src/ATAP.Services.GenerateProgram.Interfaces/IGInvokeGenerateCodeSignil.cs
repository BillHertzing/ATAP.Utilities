using System;
using ATAP.Utilities.ETW;
using ATAP.Utilities.Philote;
using ATAP.Utilities.Persistence;
using ATAP.Utilities.GenerateProgram;
namespace ATAP.Services.GenerateCode
{
  public interface IGInvokeGenerateCodeSignil : IGGenerateCodeSignil {
    string PersistenceMessageFileRelativePath { get; }
    string[] PersistenceFilePaths { get; }
    string PickAndSaveMessageFileRelativePath { get; }
    string[] PickAndSaveFilePaths { get; }
    string DBConnectionString { get; }
    string OrmLiteDialectProviderStringDefault { get; }
    new IPhilote<IGInvokeGenerateCodeSignil> Philote {get; }
  }

}
