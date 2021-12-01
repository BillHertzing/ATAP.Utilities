using System.Collections.Generic;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {

  public record GDelegateDeclarationId<TValue> : AbstractStronglyTypedId<TValue>, IGDelegateDeclarationId<TValue> where TValue : notnull {}
  public class GDelegateDeclaration<TValue> : IGDelegateDeclaration<TValue> where TValue : notnull {
    public GDelegateDeclaration(string gName = default, string gType = default, string gVisibility = default,
      Dictionary<IGArgumentId<TValue>, IGArgument<TValue>> gArguments = default,
      IGComment gComment = default) {
      GName = gName == default ? "" : gName;
      GVisibility = gVisibility == default ? "" : gVisibility;
      GType = gType == default ? "" : gType;
      GArguments = gArguments == default ? new Dictionary<IGArgumentId<TValue>, IGArgument<TValue>>() : gArguments;
      GComment = gComment == default ? new GComment() : gComment;
      Id = new GDelegateDeclarationId<TValue>();
    }
    public string GName { get; init; }
    public string GType { get; init; }
    // ToDo: make this an enumeration
    public string GVisibility { get; init; }
    public IGComment GComment { get; init; }
    public Dictionary<IGArgumentId<TValue>, IGArgument<TValue>> GArguments { get; init; }

    public  IGDelegateDeclarationId Id { get; init; }

  }
}







