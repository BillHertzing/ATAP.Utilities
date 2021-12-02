using System.Collections.Generic;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {


  public interface IGClassId<TValue> : IAbstractStronglyTypedId<TValue> where TValue : notnull {}
  public interface IGClass<TValue> where TValue : notnull {
    string GName { get; init; }
    string GVisibility { get; }
    string GAccessModifier { get; init; }
    string GInheritance { get; init; }
    IList<string> GImplements { get; init; }
    IDictionary<IGPropertyId<TValue>, IGProperty<TValue>> GPropertys { get; init; }
    IDictionary<IGPropertyGroupId<TValue>, IGPropertyGroup<TValue>> GPropertyGroups { get; init; }
    IDictionary<IGMethodId<TValue>, IGMethod<TValue>> GMethods { get; init; }
    IDictionary<IGMethodGroupId<TValue>, IGMethodGroup<TValue>> GMethodGroups { get; init; }
    IDictionary<IGStaticVariableId<TValue>, IGStaticVariable<TValue>> GStaticVariables { get; init; }
    IDictionary<IGStaticVariableGroupId<TValue>, IGStaticVariableGroup<TValue>> GStaticVariableGroups { get; init; }
    IDictionary<IGConstStringId<TValue>, IGConstString<TValue>>? GConstStrings { get; init; }
    IDictionary<IGConstStringGroupId<TValue>, IGConstStringGroup<TValue>>? GConstStringGroups { get; init; }
    IDictionary<IGDelegateId<TValue>, IGDelegate<TValue>> GDelegates { get; init; }
    IDictionary<IGDelegateGroupId<TValue>, IGDelegateGroup<TValue>> GDelegateGroups { get; init; }
    IDictionary<IGEnumerationId<TValue>, IGEnumeration<TValue>> GEnumerations { get; init; }
    IDictionary<IGEnumerationGroupId<TValue>, IGEnumerationGroup<TValue>> GEnumerationGroups { get; init; }
    IList<string>? GDisposesOf { get; init; }
    IGComment<TValue> GComment { get; init; }
    IList<IGStateConfiguration<TValue>> GStateConfigurations { get; init; }
    IGClassId<TValue> Id { get; init; }
  }
}



