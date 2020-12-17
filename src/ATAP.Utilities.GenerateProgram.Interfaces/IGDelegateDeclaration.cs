using System.Collections.Generic;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public interface IGDelegateDeclaration {
    string GName { get; init; }
    string GType { get; init; }
    string GVisibility { get; init; }
    IGComment GComment { get; init; }
    Dictionary<IPhilote<IGArgument>, IGArgument> GArguments { get; init; }
    IPhilote<IGDelegateDeclaration> Philote { get; init; }
  }
}
