using System.ComponentModel;

namespace ATAP.Utilities.RealEstate.Enumerations
{
  public enum Operation
  {
    //ToDo: Add [LocalizedDescription("PropertySearch", typeof(Resource))]
    [Description("Generic")]
    Generic = 0,
    [Description("PropertySearch")]
    PropertySearch = 1,
    [Description("PropertyLastSaleInfo")]
    PropertyLastSaleInfo = 2,
    [Description("PropertyCurrentAgent")]
    PropertyCurrentAgent = 3
  }
}
