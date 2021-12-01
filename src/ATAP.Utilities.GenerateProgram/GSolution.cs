using System;

using ATAP.Utilities.StronglyTypedId;
namespace ATAP.Utilities.GenerateProgram
{
    public class GSolution{


 public GSolution(GSolutionSignil gSolutionSignil = default
    ) {
            GSolutionSignil = gSolutionSignil ?? throw new ArgumentNullException(nameof(gSolutionSignil));

      Id = new GSolutionId<TValue>();
    }

    public GSolutionSignil GSolutionSignil { get; }
    public GSolutionId Id { get; }

    }
}






