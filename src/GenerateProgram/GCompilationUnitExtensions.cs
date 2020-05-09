using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using ATAP.Utilities.Philote;
using GenerateProgram;

namespace GenerateProgram {
  public static partial class GCompilationUnitExtensions {
    public static GCompilationUnit CompilationUnitStringConstantsConstructor(String gNamespaceName, string gRelativePath = default, GPatternReplacement gPatternReplacement = default) {
      GClass gClass = new GClass("StringConstants", gVisibility: "public", "static");
      GConstStringGroup gConstStringGroup = new GConstStringGroup(gName: "Settings File Names");
      foreach (var kvp in new Dictionary<string, string>() {
        {"SettingsFileName","AssemblyUnitNameReplacementPattern"},
        {"SettingsFileNameSuffix","json"},
      }) {
        GConstString gConstString = new GConstString(kvp.Key, kvp.Value);
        gConstStringGroup.GConstStrings[gConstString.Philote] = gConstString;
      }
      gClass.GConstStringGroups[gConstStringGroup.Philote] = gConstStringGroup;
      gConstStringGroup = new GConstStringGroup(gName: "Temporary File Names");
      foreach (var kvp in new Dictionary<string, string>() {
        {"TemporaryDirectoryBaseConfigRootKey","TemporaryDirectoryBase"},
        {"TemporaryDirectoryBaseDefault","D:/Temp/AssemblyUnitNameReplacementPattern/"},
      }) {
        GConstString gConstString = new GConstString(kvp.Key, kvp.Value);
        gConstStringGroup.GConstStrings[gConstString.Philote] = gConstString;
      }
      gClass.GConstStringGroups[gConstStringGroup.Philote] = gConstStringGroup;
      GNamespace gNamespace = new GNamespace(gNamespaceName);
      gNamespace.GClasss[gClass.Philote] = gClass;
      GCompilationUnit newgCompilationUnit = new GCompilationUnit(gName: "StringConstants", gRelativePath, gPatternReplacement: gPatternReplacement);
      newgCompilationUnit.GNamespaces[gNamespace.Philote] = (gNamespace);
      return newgCompilationUnit;
    }

    public static GCompilationUnit CompilationUnitDefaultConfigurationConstructor(String gNamespaceName, string gRelativePath = default,
      GStatementList gAdditionalStatements =default, GPatternReplacement gPatternReplacement = default) {
      GCompilationUnit gCompilationUnit = new GCompilationUnit(gName: "DefaultConfiguration", gRelativePath, gPatternReplacement: gPatternReplacement);
      foreach (var o in new List<GUsing>() {new GUsing("System.Collections.Generic")}) {
        gCompilationUnit.GUsings[o.Philote] = o;
      }

      GNamespace gNamespace = new GNamespace(gNamespaceName);

      GClass gClass = new GClass("DefaultConfiguration", gVisibility: "public", gAccessModifier: "static");
      GStaticVariable gStaticVariable = new GStaticVariable(gName:"Production", gType:"Dictionary<string,string>", gVisibility: "public",gAccessModifier: "static",
        gStaticVariableBody: new GStaticVariableBody(new List<string>() {
          "  new Dictionary<string, string> {",
          "    {StringConstants.PlaceholderConfigKey, StringConstants.PlaceholderStringDefault},",
          "  };",
        }),
        gAdditionalStatements:gAdditionalStatements
        );
      gClass.GStaticVariables[gStaticVariable.Philote] = gStaticVariable;

      gNamespace.GClasss[gClass.Philote] = gClass;
      gCompilationUnit.GNamespaces[gNamespace.Philote] =gNamespace;
      return gCompilationUnit;
    }
       

  }
}
