using System.Collections.Generic;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {
  public interface IGSolutionId<TValue> : IAbstractStronglyTypedId<TValue> where TValue : notnull {}
  public interface IGSolution<TValue> where TValue : notnull {
    IGSolutionSignil<TValue> GSolutionSignil { get; }
    IGSolutionId<TValue> Id { get; init; }
  }
}


