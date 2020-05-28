using System;
using System.Collections.Generic;
using System.Text;
using ATAP.Utilities.Philote;

namespace GenerateProgram {
  public class GMethod {
    public GMethod(GMethodDeclaration gDeclaration = default, GBody gBody = default,
      GComment gComment = default, bool isForInterface = false,
      IEnumerable<GStateConfiguration> gStateConfigurations = default) {
      GDeclaration = gDeclaration == default ? new GMethodDeclaration() : gDeclaration;
      GBody = gBody == default ? new GBody() : gBody;
      GComment = gComment == default ? new GComment() : gComment;
      IsForInterface = isForInterface;
      GStateConfigurations = new List<GStateConfiguration>();
      if (gStateConfigurations != default) {
        foreach (var sc in gStateConfigurations) {
          GStateConfigurations.Add(sc);
        }
      }
      Philote = new Philote<GMethod>();
    }

    public GMethodDeclaration GDeclaration { get; }
    public GBody GBody { get; }
    public GComment GComment { get; }
    public bool IsForInterface { get; }
    public List<GStateConfiguration> GStateConfigurations { get; }
    public Philote<GMethod> Philote { get; }
  }
}

