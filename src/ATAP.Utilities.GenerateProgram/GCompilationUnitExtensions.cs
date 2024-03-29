using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using ATAP.Utilities.StronglyTypedId;
using ATAP.Utilities.GenerateProgram;

namespace ATAP.Utilities.GenerateProgram {
  public static partial class GCompilationUnitExtensions {
    public static IGCompilationUnit CompilationUnitStringConstantsConstructor(String gNamespaceName,
      string gRelativePath = default, IGPatternReplacement gPatternReplacement = default) {
      GClass gClass = new GClass("StringConstants", gVisibility: "public", "static");
      GConstStringGroup gConstStringGroup = new GConstStringGroup(gName: "Settings File Names");
      foreach (var kvp in new Dictionary<string, string>() {
        {"SettingsFileName", "AssemblyUnitNameReplacementPattern"}, {"SettingsFileNameSuffix", "json"},
      }) {
        GConstString gConstString = new GConstString(kvp.Key, kvp.Value);
        gConstStringGroup.GConstStrings.Add(gConstString.Id, gConstString);
      }
      gClass.GConstStringGroups[gConstStringGroup.Id] = gConstStringGroup;
      gConstStringGroup = new GConstStringGroup(gName: "Temporary File Names");
      foreach (var kvp in new Dictionary<string, string>() {
        {"TemporaryDirectoryBaseConfigRootKey", "TemporaryDirectoryBase"},
        {"TemporaryDirectoryBaseDefault", "D:/Temp/AssemblyUnitNameReplacementPattern/"},
      }) {
        GConstString gConstString = new GConstString(kvp.Key, kvp.Value);
        gConstStringGroup.GConstStrings[gConstString.Id] = gConstString;
      }
      gClass.GConstStringGroups[gConstStringGroup.Id] = gConstStringGroup;
      GNamespace gNamespace = new GNamespace(gNamespaceName);
      gNamespace.GClasss.Add(gClass.Id, gClass);
      var gCompilationUnit = new GCompilationUnit(gName: "StringConstants", gRelativePath,
        gPatternReplacement: gPatternReplacement);
      gCompilationUnit.GNamespaces.Add(gNamespace.Id, gNamespace);
      return gCompilationUnit;
    }
    public static IGCompilationUnit CompilationUnitDefaultConfigurationConstructor(String gNamespaceName,
      string gRelativePath = default,
      List<string> gAdditionalStatements = default, GPatternReplacement gPatternReplacement = default) {
      GCompilationUnit gCompilationUnit = new GCompilationUnit(gName: "DefaultConfiguration", gRelativePath,
        gPatternReplacement: gPatternReplacement);
      foreach (var o in new List<IGUsing>() {new GUsing("System.Collections.Generic")}) {
        gCompilationUnit.GUsings.Add(o.Id, o);
      }
      GNamespace gNamespace = new GNamespace(gNamespaceName);

      GClass gClass = new GClass("DefaultConfiguration", gVisibility: "public", gAccessModifier: "static");
      GStaticVariable gStaticVariable = new GStaticVariable(gName: "Production", gType: "Dictionary<string,string>",
        gVisibility: "public", gAccessModifier: "",
        gBody: new GBody(new List<string>() {
          "new Dictionary<string, string> {",
          //"  {StringConstants.PlaceholderConfigKey, StringConstants.PlaceholderStringDefault},",
          "}",
        }),
        gAdditionalStatements: gAdditionalStatements
      );
      gClass.GStaticVariables.Add(gStaticVariable.Id, gStaticVariable);

      gNamespace.GClasss[gClass.Id] = gClass;
      gCompilationUnit.GNamespaces.Add(gNamespace.Id, gNamespace);
      return gCompilationUnit;
    }
  }
}



