using System;
using System.Collections.Generic;
using System.Text;

namespace ATAP.Utilities.ZSandbox
{
  public class enumMaterializedValue
  {
    public int IntValue { get; set; }
    public string StrValue { get; set; }
    public enumMaterializedValue() { }
  }

  class DynamicEnumList
  {
    public static List<enumMaterializedValue> BuildList<T>() where T : System.Enum
    {
      //ToDo: eventually convert to LINQ syntax
      var result = new List<enumMaterializedValue>();
      var values = Enum.GetValues(typeof(T));

      foreach (int item in values)
        result.Add(new enumMaterializedValue { IntValue = item, StrValue = Enum.GetName(typeof(T), item) });
      return result;
    }
  }
}
