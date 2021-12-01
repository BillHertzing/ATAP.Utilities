using System.Collections.Generic;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {
  public interface IGClass {
    string GName { get; init; }
    string GVisibility { get; }
    string GAccessModifier { get; init; }
    string GInheritance { get; init; }
    IList<string> GImplements { get; init; }
    IDictionary<IPhilote<IGProperty>, IGProperty> GPropertys { get; init; }
    IDictionary<IPhilote<IGPropertyGroup>, IGPropertyGroup> GPropertyGroups { get; init; }
    IDictionary<IPhilote<IGMethod>, IGMethod> GMethods { get; init; }
    IDictionary<IPhilote<IGMethodGroup>, IGMethodGroup> GMethodGroups { get; init; }
    IDictionary<IPhilote<IGStaticVariable>, IGStaticVariable> GStaticVariables { get; init; }
    IDictionary<IPhilote<IGStaticVariableGroup>, IGStaticVariableGroup> GStaticVariableGroups { get; init; }
    IDictionary<IPhilote<IGConstString>, IGConstString>? GConstStrings { get; init; }
    IDictionary<IPhilote<IGConstStringGroup>, IGConstStringGroup>? GConstStringGroups { get; init; }
    IDictionary<IPhilote<IGDelegate>, IGDelegate> GDelegates { get; init; }
    IDictionary<IPhilote<IGDelegateGroup>, IGDelegateGroup> GDelegateGroups { get; init; }
    IDictionary<IPhilote<IGEnumeration>, IGEnumeration> GEnumerations { get; init; }
    IDictionary<IPhilote<IGEnumerationGroup>, IGEnumerationGroup> GEnumerationGroups { get; init; }
    IList<string>? GDisposesOf { get; init; }
    IGComment GComment { get; init; }
    IList<IGStateConfiguration> GStateConfigurations { get; init; }
    IPhilote<IGClass> Philote { get; init; }
  }
}

