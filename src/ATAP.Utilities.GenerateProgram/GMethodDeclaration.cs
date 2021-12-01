using System.Collections.Generic;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {

  public record GMethodDeclarationId<TValue> : AbstractStronglyTypedId<TValue>, IGMethodDeclarationId<TValue> where TValue : notnull {}
  public class GMethodDeclaration<TValue> : IGMethodDeclaration<TValue> where TValue : notnull {
    public GMethodDeclaration(string gName = default, string gType = default, string gVisibility = default, string gAccessModifier = default,
      bool isStatic = default, bool isConstructor = default,
      IDictionary<IGArgumentId<TValue>, IGArgument<TValue>> gArguments = default,
      string gBase = default, string gThis = default, bool isForInterface = false) {
      GName = gName == default ? "" : gName;
      GVisibility = gVisibility == default ? "" : gVisibility;
      GType = gType == default ? "" : gType;
      GAccessModifier = gAccessModifier == default ? "" : gAccessModifier;
      IsStatic = isStatic == default ? false : (bool)isStatic;
      IsConstructor = isConstructor == default ? false : (bool)isConstructor;
      GArguments = gArguments == default ? new Dictionary<IGArgumentId<TValue>, IGArgument<TValue>>() : gArguments;
      GBase = gBase == default ? "" : gBase;
      GThis = gThis == default ? "" : gThis;
      IsForInterface = isForInterface;
      Id = new GMethodDeclarationId<TValue>();
    }
    public string GName { get; init; }
    public string GType { get; init; }
    // ToDo: make this an enumeration
    public string GAccessModifier { get; init; }
    public bool IsConstructor { get; init; }
    public string GVisibility { get; init; }
    public bool IsStatic { get; init; }
    public IDictionary<IGArgumentId<TValue>, IGArgument<TValue>> GArguments { get; init; }
    public string GBase { get; init; }
    public string GThis { get; set; }
    public bool IsForInterface { get; init; }
    public  IGMethodDeclarationId Id { get; init; }

  }
}






