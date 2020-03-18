using UnitsNet;

namespace ATAP.Utilities.ComputerInventory.Hardware
{
  public interface ITempAndFan
  {
    Ratio FanPct { get; set; }
    Temperature Temp { get; set; }
}
}
