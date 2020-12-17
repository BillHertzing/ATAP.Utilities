using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
   public class GDelegate : IGDelegate {
    public GDelegate(IGDelegateDeclaration gDelegateDeclaration = default, IGComment gComment = default) {
      GDelegateDeclaration = gDelegateDeclaration == default ? new GDelegateDeclaration() : gDelegateDeclaration;
      GComment = gComment == default ? new GComment() : gComment;
      Philote = new Philote<GDelegate>();
    }

    public IGDelegateDeclaration GDelegateDeclaration { get; init; }
    public IGComment GComment { get; init; }
    public IPhilote<IGDelegate> Philote { get; init; }
  }
}

