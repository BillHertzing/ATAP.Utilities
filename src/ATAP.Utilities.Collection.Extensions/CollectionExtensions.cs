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
    /// Will Throw an exception if a key duplicate occurs
    public static Dictionary<K, V> Merge<K, V>(IEnumerable<Dictionary<K, V>> dictionaries) {
      return dictionaries.SelectMany(x => x)
        .ToDictionary(x => x.Key, y => y.Value);
    }
    /// <summary>
    /// 
    /// </summary>
    /// <attribution>
    /// https://stackoverflow.com/questions/3982448/adding-a-dictionary-to-another
    /// </attribution>
    /// <typeparam name="T"></typeparam>
    /// <typeparam name="S"></typeparam>
    /// <param name="source"></param>
    /// <param name="collection"></param>
    public static void AddRange<TKey, TValue>(this Dictionary<TKey, TValue> source, IEnumerable<KeyValuePair<TKey, TValue>> collection) {
      if (collection == null) {
        return;
      }

      foreach (var item in collection) {
        if (!source.ContainsKey(item.Key)) {
          source.Add(item.Key, item.Value);
        }
        else {
          // ToDo: handle duplicate key issue here, see attribution for some options
          throw new ArgumentException(" An element with the same key already exists in the Dictionary<TKey, TValue>");
        }
      }
    }

    /// <summary>
    /// 
    /// </summary>
    /// <attribution>
    /// https://stackoverflow.com/questions/3982448/adding-a-dictionary-to-another
    /// </attribution>
    /// <typeparam name="T"></typeparam>
    /// <typeparam name="S"></typeparam>
    /// <param name="source"></param>
    /// <param name="collection"></param>
    public static void AddRange<TValue>(this IList<TValue> source, IEnumerable<TValue> collection) {
      if (collection == null) {
        return;
      }
      foreach (var item in collection) {
        source.Add(item);
      }
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
