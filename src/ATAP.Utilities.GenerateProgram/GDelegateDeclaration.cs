using System.Collections.Generic;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public class GDelegateDeclaration : IGDelegateDeclaration {
    public GDelegateDeclaration(string gName = default, string gType = default, string gVisibility = default,
      Dictionary<IPhilote<IGArgument>, IGArgument> gArguments = default,
      IGComment gComment = default) {
      GName = gName == default ? "" : gName;
      GVisibility = gVisibility == default ? "" : gVisibility;
      GType = gType == default ? "" : gType;
      GArguments = gArguments == default ? new Dictionary<IPhilote<IGArgument>, IGArgument>() : gArguments;
      GComment = gComment == default ? new GComment() : gComment;
      Philote = new Philote<GDelegateDeclaration>();
    }
    public string GName { get; init; }
    public string GType { get; init; }
    // ToDo: make this an enumeration
    public string GVisibility { get; init; }
    public IGComment GComment { get; init; }
    public Dictionary<IPhilote<IGArgument>, IGArgument> GArguments { get; init; }

    public IPhilote<IGDelegateDeclaration> Philote { get; init; }

  }
}
