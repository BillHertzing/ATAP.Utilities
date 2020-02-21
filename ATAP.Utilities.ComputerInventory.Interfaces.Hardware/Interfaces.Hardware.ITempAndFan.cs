namespace ATAP.Utilities.ComputerInventory.Interfaces.Hardware
{
  public interface ITempAndFan
  {
    double FanPct { get; set; }
    double Temp { get; set; }
  }
}
