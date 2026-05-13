using System.Collections.Generic;
using System.Collections;
using ATAP.Utilities.RealEstate.Enumerations;
using System;

namespace ATAP.Utilities.RealEstate.Enumerations.UnitTests
{

  //ToDo add validation tests to ensure illegal values are not allowed.  This applies to all XxTestDataGenerator classes
  public class OperationTestData
  {
    public Operation Operation { get; set; }
    public string SerializedOperation { get; set;  }

    public OperationTestData()
    {
    }

    public OperationTestData(Operation operation, string serializedOperation)
    {
      Operation = operation;
      SerializedOperation = serializedOperation ?? throw new ArgumentNullException(nameof(serializedOperation));
    }
  }

  public class OperationTestDataGenerator : IEnumerable<object[]>
  {
    public static IEnumerable<object[]> OperationTestData()
    {
      yield return new OperationTestData[] { new OperationTestData { Operation = Operation.Generic, SerializedOperation = "0" } };
      yield return new OperationTestData[] { new OperationTestData { Operation = Operation.PropertySearch, SerializedOperation = "1" } };
      yield return new OperationTestData[] { new OperationTestData { Operation = Operation.PropertyLastSaleInfo, SerializedOperation = "2" } };
      yield return new OperationTestData[] { new OperationTestData { Operation = Operation.PropertyCurrentAgent, SerializedOperation = "\"3\"" } };
    }
    public IEnumerator<object[]> GetEnumerator() { return OperationTestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }
}
