using System;
using Xunit;
using Xunit.Abstractions;
using FluentAssertions;
using ATAP.Utilities.RealEstate.Enumerations;
using ATAP.Utilities.Enumeration;
using System.Collections.Generic;

namespace ATAP.Utilities.RealEstate.Enumerations.UnitTests
{
  public class Fixture
  {
    // The correct answer to the test OperationEnumerationCountIsAsExpected
    public readonly int NumberOfOperationEnumerations = 3;

    public Fixture()
    {

    }
  }


  public class RealEstateEnumerationsUnitTests001 : IClassFixture<Fixture>
    {
    protected Fixture fixture;
    public RealEstateEnumerationsUnitTests001(Fixture fixture)
    {
      this.fixture = fixture;
    }

    [Fact]
    // Test that the number of members of this enumeration is correct
    public void OperationEnumerationCountAsExpected()
    {
      int result = Enum.GetValues(typeof(Operation)).Length;

      Assert.True(result == fixture.NumberOfOperationEnumerations);
    }


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
  }
}
