using System;
using System.Collections.Generic;

using ATAP.Utilities.Philote;
namespace ATAP.Utilities.GenerateProgram {

  public class GGenerateProgamProgress :  IGGenerateProgramProgress {
    public GGenerateProgamProgress() {
      Philote = new Philote<IGGenerateProgramProgress>();
    }

    public void Report(string message) {  }
    public IPhilote<IGGenerateProgramProgress> Philote { get; init; }
  }
}
