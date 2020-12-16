using System;
using System.Collections.Generic;
using System.Text;
using ATAP.Utilities.Philote;

namespace GenerateProgram {
  public class GDelegate {
    public GDelegate( GDelegateDeclaration gDelegateDeclaration = default, GComment gComment = default) {
      GDelegateDeclaration = gDelegateDeclaration == default? new GDelegateDeclaration() : gDelegateDeclaration;
      GComment = gComment == default? new GComment() : gComment;
      Philote = new Philote<GDelegate>();
    }

    public GDelegateDeclaration GDelegateDeclaration { get; }
    public GComment GComment { get; }
    public Philote<GDelegate> Philote { get; }
  }
}

