using System.Collections.Generic;

using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {


  public interface IGGenerateProgramResultId<TValue> : IAbstractStronglyTypedId<TValue> where TValue : notnull {}
  public interface IGGenerateProgramResult<TValue> where TValue : notnull {
    bool DBExtractionSuccess { get; init; }
    bool BuildSuccess { get; init; }
    bool UnitTestsSuccess { get; init; }
    double UnitTestsCoverage { get; init; }
    string GeneratedSolutionFileDirectory { get; init; }
    IDictionary<IGGenerateProgramResultId<TValue>, IGGenerateProgramResult<TValue>> Id { get; init; }
  }

}



