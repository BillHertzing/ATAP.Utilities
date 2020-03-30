using System.ComponentModel;

namespace ATAP.Utilities.ComputerInventory.Software
{
   public enum SupportedKindsOfHostBuilders
  {
    //ToDo: Add [LocalizedDescription("ConsoleHostBuilder", typeof(Resource))]
    [Description("ConsoleHostBuilder")]
    ConsoleHostBuilder = 0,
    [Description("WebHostBuilder")]
    WebHostBuilder = 1
  }

  // Create an enumeration for the kinds of WebHostBuilders supported
  public enum SupportedWebHostBuilders
  {
    //ToDo: Add [LocalizedDescription("IntegratedIISInProcessWebHostBuilder", typeof(Resource))]
    [Description("IntegratedIISInProcessWebHostBuilder")]
    IntegratedIISInProcessWebHostBuilder = 0,
    [Description("KestrelAloneWebHostBuilder")]
    KestrelAloneWebHostBuilder = 1
  }

  // Create an enumeration for the GenricHost Lifetimes supported
  public enum SupportedGenericHostLifetimes {
    //ToDo: Add [LocalizedDescription("ConsoleLifetime", typeof(Resource))]
    [Description("ConsoleLifetime")]
    ConsoleLifetime = 0,
    [Description("ServiceLifetime")]
    ServiceLifetime = 1
  }

  

}

