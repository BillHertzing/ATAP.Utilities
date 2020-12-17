using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public interface IGDelegate {
    IGDelegateDeclaration GDelegateDeclaration { get; init; }
    IGComment GComment { get; init; }
    IPhilote<IGDelegate> Philote { get; init; }
  }
}
