using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace ATAP.Utilities.GenerateProgram {
  public static class Lookup {
    public static (
      IEnumerable<IGAssemblyUnit> gAssemblyUnits,
      IEnumerable<IGCompilationUnit> gCompilationUnits,
      IEnumerable<IGNamespace> gNamespacess,
      IEnumerable<IGClass> gClasss,
      IEnumerable<IGMethod> gMethods)
      LookupPrimaryConstructorMethod(
        IEnumerable<IGAssemblyGroup> gAssemblyGroups,
        string gAssemblyGroupName = "",
        string gAssemblyUnitName = "",
        string gCompilationUnitName = "",
        string gNamespaceName = "",
        string gClassName = ""
      ) {
      var gAssemblyUnits = new List<IGAssemblyUnit>();
      var gCompilationUnits = new List<IGCompilationUnit>();
      var gNamespaces = new List<IGNamespace>();
      var gClasss = new List<IGClass>();
      var gMethods = new List<IGMethod>();
      foreach (var gAg in gAssemblyGroups) {
        if (String.IsNullOrWhiteSpace(gAssemblyGroupName) || gAg.GName == gAssemblyGroupName) {
          foreach (var gAU in gAg.GAssemblyUnits) {
            if (String.IsNullOrWhiteSpace(gAssemblyUnitName) || gAU.Value.GName == gAssemblyUnitName) {
              foreach (var gCU in gAU.Value.GCompilationUnits) {
                if (String.IsNullOrWhiteSpace(gCompilationUnitName) || gCU.Value.GName == gCompilationUnitName) {
                  foreach (var gNs in gCU.Value.GNamespaces) {
                    if (String.IsNullOrWhiteSpace(gNamespaceName) || gNs.Value.GName == gNamespaceName) {
                      foreach (var gCl in gNs.Value.GClasss) {
                        if (String.IsNullOrWhiteSpace(gClassName) || gCl.Value.GName == gClassName) {
                          foreach (var gMe in gCl.Value.CombinedMethods()) {
                            if (gMe.GDeclaration.IsConstructor) {
                              gAssemblyUnits.Add(gAU.Value);
                              gCompilationUnits.Add(gCU.Value);
                              gNamespaces.Add(gNs.Value);
                              gClasss.Add(gCl.Value);
                              gMethods.Add(gMe);
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
      return (gAssemblyUnits, gCompilationUnits, gNamespaces, gClasss, gMethods);
    }
    public static (
      IEnumerable<IGAssemblyUnit> gAssemblyUnits,
      IEnumerable<IGCompilationUnit> gCompilationUnits,
      IEnumerable<IGNamespace> gNamespacess,
      IEnumerable<IGClass> gClasss)
      LookupDerivedClass(
        IEnumerable<IGAssemblyGroup> gAssemblyGroups,
        string gAssemblyGroupName = "",
        string gAssemblyUnitName = "",
        string gCompilationUnitName = "",
        string gNamespaceName = "",
        string gClassName = ""
      ) {
      var gAssemblyUnits = new List<IGAssemblyUnit>();
      var gCompilationUnits = new List<IGCompilationUnit>();
      var gNamespaces = new List<IGNamespace>();
      var gClasss = new List<IGClass>();
      var gMethods = new List<IGMethod>();
      foreach (var gAg in gAssemblyGroups) {
        if (String.IsNullOrWhiteSpace(gAssemblyGroupName) || gAg.GName == gAssemblyGroupName) {
          foreach (var gAU in gAg.GAssemblyUnits) {
            if (String.IsNullOrWhiteSpace(gAssemblyUnitName) || gAU.Value.GName == gAssemblyUnitName) {
              foreach (var gCU in gAU.Value.GCompilationUnits) {
                if (String.IsNullOrWhiteSpace(gCompilationUnitName) || gCU.Value.GName == gCompilationUnitName) {
                  foreach (var gNs in gCU.Value.GNamespaces) {
                    if (String.IsNullOrWhiteSpace(gNamespaceName) || gNs.Value.GName == gNamespaceName) {
                      foreach (var gCl in gNs.Value.GClasss) {
                        if (String.IsNullOrWhiteSpace(gClassName) || gCl.Value.GName == gClassName) {
                          gAssemblyUnits.Add(gAU.Value);
                          gCompilationUnits.Add(gCU.Value);
                          gNamespaces.Add(gNs.Value);
                          gClasss.Add(gCl.Value);
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
      return (gAssemblyUnits, gCompilationUnits, gNamespaces, gClasss);
    }
    public static (
      IEnumerable<IGAssemblyUnit> gAssemblyUnits,
      IEnumerable<IGCompilationUnit> gCompilationUnits,
      IEnumerable<IGNamespace> gNamespacess,
      IEnumerable<IGInterface> gInterfaces
      )
      LookupInterfaces(
        IEnumerable<IGAssemblyGroup> gAssemblyGroups,
        string gAssemblyGroupName = "",
        string gAssemblyUnitName = "",
        string gCompilationUnitName = "",
        string gNamespaceName = "",
        string gInterfaceName = ""
      ) {
      var gAssemblyUnits = new List<IGAssemblyUnit>();
      var gCompilationUnits = new List<IGCompilationUnit>();
      var gNamespaces = new List<IGNamespace>();
      var gInterfaces = new List<IGInterface>();
      foreach (var gAg in gAssemblyGroups) {
        if (String.IsNullOrWhiteSpace(gAssemblyGroupName) || gAg.GName == gAssemblyGroupName) {
          foreach (var gAU in gAg.GAssemblyUnits) {
            if (String.IsNullOrWhiteSpace(gAssemblyUnitName) || gAU.Value.GName == gAssemblyUnitName) {
              foreach (var gCU in gAU.Value.GCompilationUnits) {
                if (String.IsNullOrWhiteSpace(gCompilationUnitName) || gCU.Value.GName == gCompilationUnitName) {
                  foreach (var gNs in gCU.Value.GNamespaces) {
                    if (String.IsNullOrWhiteSpace(gNamespaceName) || gNs.Value.GName == gNamespaceName) {
                      foreach (var gIn in gNs.Value.GInterfaces) {
                        if (String.IsNullOrWhiteSpace(gInterfaceName) || gIn.Value.GName == gInterfaceName) {
                          gAssemblyUnits.Add(gAU.Value);
                          gCompilationUnits.Add(gCU.Value);
                          gNamespaces.Add(gNs.Value);
                          gInterfaces.Add(gIn.Value);
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
      return (gAssemblyUnits, gCompilationUnits, gNamespaces, gInterfaces);
    }
    public static (
      IEnumerable<IGAssemblyUnit> gAssemblyUnits,
      IEnumerable<IGProjectUnit> gProjectUnits
      )
    LookupProjectUnits(
      IEnumerable<IGAssemblyGroup> gAssemblyGroups,
      string gAssemblyGroupName = "",
      string gAssemblyUnitName = "",
      string gProjectUnitName = ""
    ) {
var gAssemblyUnits = new List<IGAssemblyUnit>();
      var gProjectUnits = new List<IGProjectUnit>();
      foreach (var gAg in gAssemblyGroups) {
        if (String.IsNullOrWhiteSpace(gAssemblyGroupName) || gAg.GName == gAssemblyGroupName) {
          foreach (var gAU in gAg.GAssemblyUnits) {
            if (String.IsNullOrWhiteSpace(gAssemblyUnitName) || gAU.Value.GName == gAssemblyUnitName) {
              gAssemblyUnits.Add(gAU.Value);
              gProjectUnits.Add(gAU.Value.GProjectUnit);
            }
          }
        }
      }
      return (gAssemblyUnits, gProjectUnits);
    }
  }
}
