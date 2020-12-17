using System.Collections.Generic;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public interface IGStaticVariable {
    string GName { get; init; }
    string GType { get; init; }
    string GAccessModifier { get; init; }
    string GVisibility { get; init; }
    IGBody GBody { get; init; }
    IList<string> GAdditionalStatements { get; init; }
    IGComment GComment { get; init; }
    IPhilote<IGStaticVariable> Philote { get; init; }
  }
}
