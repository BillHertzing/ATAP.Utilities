using System;
using System.Collections.Generic;

namespace ATAP.Utilities.Testing
{
  //ToDo add validation tests to ensure illegal values are not allowed.  This applies to all XxTestDataGenerator classes
  public class SerializedTestData<T>
  {
    public T ObjTestData;
    public string TestData;


    public SerializedTestData(T objTestData, string testData)
    {
      ObjTestData = objTestData ?? throw new ArgumentNullException(nameof(objTestData));
      TestData =  testData ?? throw new ArgumentNullException(nameof(testData)) ;
    }

  }
  public class TestDataEn<T>
  {
    public IEnumerable<SerializedTestData<T>> E;

    public TestDataEn(IEnumerable<SerializedTestData<T>> e)
    {
      E = e ?? throw new ArgumentNullException(nameof(e));
    }
  }
}
