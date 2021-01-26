using System;
using System.Collections.Generic;

namespace ATAP.Utilities.Persistence
{
  public class PickAndSave<Tout> : IPersistence<Tout> where Tout : IInsertResultsAbstract {

    public PickAndSave(Func<object, bool> pickFunc, Func<IEnumerable<IEnumerable<object>>, Tout> insertEnumerableFunc) {
      PickFunc = pickFunc;
      InsertEnumerableFunc = insertEnumerableFunc;
    }
    public PickAndSave(Func<object, bool> pickFunc, Func<IDictionary<string, IEnumerable<object>>, Tout> insertDictionaryFunc) {
      PickFunc = pickFunc;
      InsertDictionaryFunc = insertDictionaryFunc;
    }
    public Func<object, bool> PickFunc { get; private set; }
    public Func<IEnumerable<IEnumerable<object>>, Tout> InsertEnumerableFunc { get; private set; }
    public Func<IDictionary<string, IEnumerable<object>>, Tout> InsertDictionaryFunc { get; private set; }
  }

}
