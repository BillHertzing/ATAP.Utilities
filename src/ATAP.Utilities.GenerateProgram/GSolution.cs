using System;
using System.Collections.Generic;

using ATAP.Utilities.StronglyTypedId;
namespace ATAP.Utilities.GenerateProgram {
    public record GSolutionId<TValue> : AbstractStronglyTypedId<TValue>, IGSolutionId<TValue> where TValue : notnull {}

  public class GSolution<TValue> : IGSolution<TValue> where TValue : notnull {
    public GSolution(GSolutionSignil<TValue> gSolutionSignil = default) {
      GSolutionSignil = gSolutionSignil ?? throw new ArgumentNullException(nameof(gSolutionSignil));
      Id = new GSolutionId<TValue>();
    }

    public IGSolutionSignil<TValue> GSolutionSignil { get; init; }
    public IGSolutionId<TValue> Id { get; init; }
  }
}






