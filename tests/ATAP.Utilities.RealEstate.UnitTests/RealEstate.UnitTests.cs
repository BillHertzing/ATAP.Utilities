using System;
using Xunit;
using Xunit.Abstractions;
using FluentAssertions;
using ATAP.Utilities.RealEstate.Enumerations;
using ATAP.Utilities.Enumeration;
using System.Collections.Generic;
using ATAP.Utilities.Testing;

namespace ATAP.Utilities.RealEstate.Enumerations.UnitTests
{
  public class RealEstateFixture : DiFixture
  {
    // The correct answer to the test OperationEnumerationCountIsAsExpected
    public int NumberOfOperationEnumerations { get; }

    public RealEstateFixture()
    {
      NumberOfOperationEnumerations = 3;
    }
  }


  public class RealEstateUnitTests001 : IClassFixture<RealEstateFixture>
    {
    protected RealEstateFixture Fixture { get; }
    protected ITestOutputHelper TestOutput { get; }

    public RealEstateUnitTests001(ITestOutputHelper testOutput, RealEstateFixture fixture)
    {
      Fixture = fixture;
      TestOutput = testOutput;
    }


    [Theory]
    [MemberData(nameof(OperationTestDataGenerator.OperationTestData), MemberType = typeof(OperationTestDataGenerator))]
    public void OperationEnumerationDeserializeFromJSON(OperationTestData inRealEstateTestData)
    {
      var realEstate = Fixture.Serializer.Deserialize<Operation>(inRealEstateTestData.SerializedOperation);
      realEstate.Should().BeOfType(typeof(Operation));
      Fixture.Serializer.Deserialize<Operation>(inRealEstateTestData.SerializedOperation).Should().Be(inRealEstateTestData.Operation);
    }

    [Theory]
    [MemberData(nameof(OperationTestDataGenerator.OperationTestData), MemberType = typeof(OperationTestDataGenerator))]
    public void OperationEnumerationSerializeToJSON(OperationTestData inRealEstateTestData)
    {
      string str = Fixture.Serializer.Serialize(inRealEstateTestData.SerializedOperation);
      str.Should().Be(inRealEstateTestData.SerializedOperation);
    }

    // ToDo Add tests for additional enumeration attributes, and localized values of those attributes
    /*
    [Theory]
    // ToDo: Replace this theory's InlineData with external configuration file data
    [InlineData("PropertySearch","PropertyLastSaleInfo","PropertyCurrentAgent")]
    // Test that the custom Description attributes of members of this enumeration are correct
    public void OperationEnumerationDescriptionStringsAsExpected(params string[] descriptionStrings)
    {
      var operations = Enum.GetValues(typeof(Operation));
      string[] result = new string[operations.Length] ;
      int i = 0;
      foreach (Operation e in operations)
      {
        result[i++] = ATAP.Utilities.Enumeration.Utilities.GetDescription(e);
      }
      Array.Sort(descriptionStrings);
      Array.Sort(result);
      var str1 = result.ToString();
      var str2 = descriptionStrings.ToString();
      str1.Should().Match(str2);
    }
    */
  }
}
