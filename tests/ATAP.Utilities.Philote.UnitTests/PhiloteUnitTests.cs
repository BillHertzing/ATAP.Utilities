


using ATAP.Utilities.Testing;
using FluentAssertions;
using Xunit;
using Xunit.Abstractions;
using ATAP.Utilities.Philote;
using ATAP.Utilities.Testing.XunitSkipAttributeExtension;
using System.Collections.Generic;
using System;
using System.Diagnostics.CodeAnalysis;

namespace ATAP.Utilities.Philote.UnitTests
{

  /* Save the following comment4ed block for a StackOverflow question on how yo get the IdType to be the interface for the concrete class, and not the interface for the abstract class
  // Covariance test classes
  //======================================
  public interface IXId<T> { }
  public class XId<T> :  IXId<T>
  {
    Guid Guid { get; set; }

    public XId(string value)
    {
      bool success;
      if (string.IsNullOrEmpty(value))
      {
        this.Guid = Guid.NewGuid();
      }
      else
      {
        success = Guid.TryParse(value, out Guid newValue);
        if (!success) { throw new NotSupportedException($"Guid.TryParse failed,, newValue {value} cannot be parsed as a GUID"); }
        this.Guid = newValue;
      }
    }

    public XId(Guid guid)
    {
      this.Guid = guid;
    }
  }
  //======================================
  public interface IP<T>
  {
    XId<T> Id { get;  }
    IEnumerable<XId<T>> AdditionalIDs { get; }
  }
  public class P<T> : IP<T>
  {
    public XId<T> Id { get; private set; }
    public IEnumerable<XId<T>> AdditionalIDs { get; private set; }
  }

  //======================================
  public interface IA
  {
    IP<IA>? P { get; }
  }

  public abstract class A
  {
    public  IP<IA>? P { get; set; }
  }
  //======================================

  public interface ID1 : IA
  {
    string? D1str { get; }
    //IP<ID1>? P { get; }
  }

  public class D1 :  A, ID1
  {
    public string? D1str { get; private set; }
    //public IP<ID1>? P { get; private set; }
  }

  public interface ID2 : IA
  {
    int? D2int { get; }
  }

  public class D2 : A, ID2
  {
    public int? D2int { get; private set; }
  }

  public class NodeSets
  {
    public IEnumerable<IA>  Nodes { get; private set; }
  }

        [Fact]
    public void NodeSetsTest()
    {
      D1 d1 = new D1();
      D2 d2 = new D2();
      IEnumerable<ID1> eD1 = new List<ID1>();
      IEnumerable<ID2> eD2 = new List<ID2>();
      NodeSets nS = new NodeSets();
      var nSNodesAsList = nS.Nodes as List<IA>;
      nSNodesAsList.Add(d1);
      nSNodesAsList.Add(d2);

    }


    End of block for StackOverflow */


  public partial class PhiloteUnitTests001 : IClassFixture<PhiloteFixture>
  {

    [Theory]
    [MemberData(nameof(PhiloteTestDataGenerator<IDummyTypeForPhiloteTest>.TestData), MemberType = typeof(PhiloteTestDataGenerator<IDummyTypeForPhiloteTest>))]
    public void PhiloteDeserializeFromJSON(PhiloteTestData<IDummyTypeForPhiloteTest> inTestData)
    {
      var obj = Fixture.Serializer.Deserialize<Philote<IDummyTypeForPhiloteTest>>(inTestData.SerializedTestData);
      // ToDo Figure out how to assert that a type implements IEnuerable<T>
      //obj.Should().BeOfType(typeof(Philote<IDummyTypeForPhiloteTest>));
      Fixture.Serializer.Deserialize<Philote<IDummyTypeForPhiloteTest>>(inTestData.SerializedTestData).Should().BeEquivalentTo(inTestData.ObjTestData);
    }

    [Theory]
    [MemberData(nameof(PhiloteTestDataGenerator<IDummyTypeForPhiloteTest>.TestData), MemberType = typeof(PhiloteTestDataGenerator<IDummyTypeForPhiloteTest>))]
    public void PhiloteSerializeToJSON(PhiloteTestData<IDummyTypeForPhiloteTest> inTestData)
    {
      Fixture.Serializer.Serialize(inTestData.ObjTestData).Should().MatchRegex(inTestData.SerializedTestData);
    }
  }
}
