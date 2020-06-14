using System;
using System.Collections.Generic;
using System.Text;
using ATAP.Utilities.Philote;

namespace GenerateProgram {
  public class GMethod {
    public GMethod(GMethodDeclaration gDeclaration = default, GBody gBody = default,
      GComment gComment = default, bool isForInterface = false,
      GStateConfiguration gStateConfiguration = default) {
      GDeclaration = gDeclaration == default ? new GMethodDeclaration() : gDeclaration;
      GBody = gBody == default ? new GBody() : gBody;
      GComment = gComment == default ? new GComment() : gComment;
      IsForInterface = isForInterface;
      GStateConfiguration = gStateConfiguration == default ? new GStateConfiguration() : gStateConfiguration;
      Philote = new Philote<GMethod>();
    }
    public GMethodDeclaration GDeclaration { get; }
    public GBody GBody { get; }
    public GComment GComment { get; }
    public bool IsForInterface { get; }
    public GStateConfiguration GStateConfiguration { get; }
    public Philote<GMethod> Philote { get; }
  }
}
