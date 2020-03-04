using System.ComponentModel;

namespace ATAP.Utilities.ComputerInventory.Enumerations
{
  public enum GPUMaker
  {
    //ToDo: Add [LocalizedDescription("Generic", typeof(Resource))]
    [Description("Generic")]
    Generic = 0,
    [Description("AMD")]
    AMD = 1,
    [Description("NVIDEA")]
    NVIDEA = 2
  }

  public enum VideoCardMaker
  {
    //ToDo: Add [LocalizedDescription("Generic", typeof(Resource))]
    [Description("Generic")]
    Generic = 0,
    [Description("ASUS")]
    ASUS = 1,
    [Description("EVGA")]
    EVGA = 2,
    [Description("MSI")]
    MSI = 3,
    [Description("PowerColor")]
    PowerColor = 4
  }

  public enum MainBoardMaker
  {
    //ToDo: Add [LocalizedDescription("Generic", typeof(Resource))]
    [Description("Generic")]
    Generic = 0,
    [Description("ASUS")]
    ASUS = 1,
    [Description("MSI")]
    MSI = 2
  }

  public enum CPUSocket
  {
    //ToDo: Add [LocalizedDescription("Generic", typeof(Resource))]
    [Description("Generic")]
    Generic = 0,
    [Description("LGA 1136")]
    LGA1136 = 1,
    [Description("LGA 1155")]
    LGA1155 = 2,
    [Description("LGA 1156")]
    LGA1156 = 3,
    [Description("LGA 775")]
    LGA775 = 4
  }

  public enum CPUMaker
  {
    //ToDo: Add [LocalizedDescription("Generic", typeof(Resource))]
    [Description("Generic")]
    Generic = 0,
    [Description("Intel")]
    Intel = 1,
    [Description("AMD")]
    AMD = 2
  }

  public enum VideoCardMemoryMaker
  {
    //ToDo: Add [LocalizedDescription("Generic", typeof(Resource))]
    [Description("Generic")]
    Generic = 0,
    [Description("Elpida")]
    Elpida = 1,
    [Description("Hynix")]
    Hynix = 2,
    [Description("Samsung")]
    Samsung = 3
  }

  public enum DiskDriveMaker
  {
    //ToDo: Add [LocalizedDescription("Generic", typeof(Resource))]
    [Description("Generic")]
    Generic = 0,
    [Description("Samsung")]
    Samsung = 1,
    [Description("Seagate")]
    Seagate = 2,
    [Description("WesternDigital")]
    WesternDigital = 3,
    [Description("Maxtor")]
    Maxtor = 4,
    [Description("Hitachi")]
    Hitachi = 5
  }
  public enum DiskDriveType
  {
    //ToDo: Add [LocalizedDescription("Generic", typeof(Resource))]
    [Description("Generic")]
    Generic = 0,
    [Description("SSD")]
    SSD = 1,
    [Description("HDD")]
    HDD = 2
  }

}
