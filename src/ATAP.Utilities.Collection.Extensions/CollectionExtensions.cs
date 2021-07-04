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
    public static Dictionary<TKey, TValue> Merge<TKey, TValue> (IEnumerable<Dictionary<TKey, TValue>> dictionaries)  where TKey : notnull{
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

    /// <summary>
    /// Add an enumerable KeyValue pair to a dictionary
    /// </summary>
    /// <attribution>
    /// https://stackoverflow.com/questions/3982448/adding-a-dictionary-to-another
    /// </attribution>
    /// <typeparam name="T"></typeparam>
    /// <typeparam name="S"></typeparam>
    /// <param name="source"></param>
    /// <param name="collection"></param>
    public static void AddRange<TKey, TValue>(this Dictionary<TKey, TValue> source, IEnumerable<KeyValuePair<TKey, TValue>> collection) where TKey : notnull {
      // ToDo: Localize the exception message
      if (source == null) { throw new ArgumentNullException(nameof(source)); }
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
    /// Add an IEnumerable to a List
    /// </summary>
    /// <typeparam name="TValue"></typeparam>
    /// <param name="source"></param>
    /// <param name="collection"></param>
    public static void AddRange<TValue>(this IList<TValue> source, IEnumerable<TValue> collection) {
      // ToDo: Localize the exception message
      if (source == null) { throw new ArgumentNullException(nameof(source)); }
      if (collection == null) {
        return;
      }
      foreach (var item in collection) {
        source.Add(item);
      }
    }
    /// <summary>
    /// Perform an Action on each element of an IEnumerable
    /// </summary>
    /// <typeparam name="T"></typeparam>
    /// <param name="source"></param>
    /// <param name="action"></param>
    public static void ForEach<T>(this IEnumerable<T> source, Action<T> action) {
      // ToDo: Localize the exception message
      if (source == null) { throw new ArgumentNullException(nameof(source)); }
      // ToDo: Localize the exception message
      if (action == null) { throw new ArgumentNullException(nameof(action)); }
      foreach (T element in source) {
        action(element);
      }
    }

    /// <summary>
    /// Static extension that adds any enumerable to any collection (handles AddRange for IList<T> to IList<T>)
    /// </summary>
    /// <typeparam name="T"></typeparam>
    /// <param name="collection"></param>
    /// <param name="enumerable"></param>
    /// <attribution>
    /// [Is there an easy way to append one IList<MyType> to another?](https://stackoverflow.com/questions/9520291/is-there-an-easy-way-to-append-one-ilistmytype-to-another)
    /// </attribution>
    public static void AddRange<T>(this ICollection<T> collection, IEnumerable<T> enumerable) {
      // ToDo: Localize the exception message
      if (enumerable == null) { throw new ArgumentNullException(nameof(enumerable)); }
      // ToDo: Localize the exception message
      if (collection == null) { throw new ArgumentNullException(nameof(collection)); }
      foreach (var cur in enumerable) {
        collection.Add(cur);
      }
    }

    public static IEnumerable<TSource> DistinctBy<TSource, TKey>(this IEnumerable<TSource> source,
    Func<TSource, TKey> keySelector) {
      // ToDo: Localize the exception message
      if (source == null) { throw new ArgumentNullException(nameof(source)); }
      // ToDo: Localize the exception message
      if (keySelector == null) { throw new ArgumentNullException(nameof(keySelector)); }
      var knownKeys = new HashSet<TKey>();
      foreach (TSource element in source) {
        if (knownKeys.Add(keySelector(element))) {
          yield return element;
        }
      }
    }

    // attribution:[How do I check if IEnumerable has a single element?](https://stackoverflow.com/questions/47830766/how-do-i-check-if-ienumerable-has-a-single-element)
    public static bool HasSingle<T>(this IEnumerable<T> sequence, out T value) {
      // ToDo: Localize the exception message
      if (sequence == null) { throw new ArgumentNullException(nameof(sequence)); }
      if (sequence is IList<T> list) {
        if (list.Count == 1) {
          value = list[0];
          return true;
        }
      }
      else {
        using var iter = sequence.GetEnumerator(); if (iter.MoveNext()) {
          value = iter.Current;
          if (!iter.MoveNext()) {
            return true;
          }
        }
      }
      value = default;
      return false;
    }

    // three Extension methods for Collections that traverse a hierarchy
    // Attribution: https://stackoverflow.com/questions/20974248/recursive-hierarchy-recursive-query-using-linq Duane McKinney
    // Attribution: https://dotnetfiddle.net/hse92w Duane McKinney

    public static IEnumerable<T> Traverse<T>(this T item, Func<T, T> childSelector) {
      // ToDo: Localize the exception message
      if (childSelector == null) { throw new ArgumentNullException(nameof(childSelector)); }
      var stack = new Stack<T>(new T[] { item });
      while (stack.Any()) {
        var next = stack.Pop();
        if (next != null) {
          yield return next;
          stack.Push(childSelector(next));
        }
      }
    }

    public static IEnumerable<T> Traverse<T>(this T item, Func<T, IEnumerable<T>> childSelector) {
      // ToDo: Localize the exception message
      if (childSelector == null) { throw new ArgumentNullException(nameof(childSelector)); }
      var stack = new Stack<T>(new T[] { item });

      while (stack.Any()) {
        var next = stack.Pop();
        //if(next != null)
        //{
        yield return next;
        foreach (var child in childSelector(next)) {
          stack.Push(child);
        }
        //}
      }
    }

    public static IEnumerable<T> Traverse<T>(this IEnumerable<T> items,
      Func<T, IEnumerable<T>> childSelector) {
              // ToDo: Localize the exception message
      if (childSelector == null) { throw new ArgumentNullException(nameof(childSelector)); }
      var stack = new Stack<T>(items);
      while (stack.Any()) {
        var next = stack.Pop();
        yield return next;
        foreach (var child in childSelector(next)) {
          stack.Push(child);
        }
      }
    }

  }
}
