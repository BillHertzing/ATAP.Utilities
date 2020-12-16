using System;

using ATAP.Utilities.Philote;
namespace ATAP.Utilities.GenerateProgram
{
    public class GSolution{


 public GSolution(GSolutionSignil gSolutionSignil = default
    ) {
            GSolutionSignil = gSolutionSignil ?? throw new ArgumentNullException(nameof(gSolutionSignil));

      Philote = new Philote<GSolution>();
    }

    public GSolutionSignil GSolutionSignil { get; }
    public Philote<GSolution> Philote { get; }

    }
}
