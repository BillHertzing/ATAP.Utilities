using System;
using ATAP.Utilities.Philote;
namespace ATAP.Utilities.GenerateProgram {
  public interface IGGenerateCodeProgress : IProgress<string> {

    IPhilote<IGGenerateCodeProgress> Philote { get; init; }
  }
}
