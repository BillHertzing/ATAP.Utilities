using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using ATAP.Utilities.ETW;


namespace ATAP.Utilities.Collection {
#if TRACE
  [ETWLogAttribute]
#endif
  public static partial class Extensions {

  /// Will Thow an exception if a key duplicate occurs
  public static Dictionary<K, V> Merge<K, V>(IEnumerable<Dictionary<K, V>> dictionaries)
{

	 return dictionaries.SelectMany(x => x)
					.ToDictionary(x => x.Key, y => y.Value);
}
/// Will take the first value if multiple keys appear

//public static Dictionary<K, V> Merge<K, V>(IEnumerable<Dictionary<K, V>> dictionaries)
//{
//	return dictionaries.SelectMany(x => x)
//					.GroupBy(d => d.Key)
//					.ToDictionary(x => x.Key, y => y.First().Value);
//}
  }

}

