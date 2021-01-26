using System;
using System.Collections.Generic;


namespace ATAP.Utilities.Persistence
{
  public class Persistence<Tout> : IPersistence<Tout> where Tout : IInsertResultsAbstract {

    public Persistence(Func<IEnumerable<IEnumerable<object>>, Tout> insertEnumerableFunc) {
      InsertEnumerableFunc = insertEnumerableFunc;
    }
    public Persistence(Func<IDictionary<string, IEnumerable<object>>, Tout> insertDictionaryFunc) {
      InsertDictionaryFunc = insertDictionaryFunc;
    }

    public Func<IEnumerable<IEnumerable<object>>, Tout> InsertEnumerableFunc { get; private set; }
    public Func<IDictionary<string, IEnumerable<object>>, Tout> InsertDictionaryFunc { get; private set; }
  }

}
