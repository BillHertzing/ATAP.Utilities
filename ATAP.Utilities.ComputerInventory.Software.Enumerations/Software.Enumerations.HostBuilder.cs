using System.ComponentModel;

namespace ATAP.Utilities.ComputerInventory.Software
{
  // Create an enumeration for the kinds of WebHostBuilders supported
  public enum SupportedWebHostBuilders
  {
    //ToDo: Add [LocalizedDescription("IntegratedIISInProcessWebHostBuilder", typeof(Resource))]
    [Description("IntegratedIISInProcessWebHostBuilder")]
    IntegratedIISInProcessWebHostBuilder = 0,
    [Description("KestrelAloneWebHostBuilder")]
    KestrelAloneWebHostBuilder = 1
  }

}

