using ATAP.Utilities.ComputerInventory.Enumerations;
using ATAP.Utilities.ComputerInventory.Enumerations.Hardware;

namespace ATAP.Utilities.ComputerInventory.Interfaces.Hardware
{
  public interface IVideoCardSignil
  {
    string CardName { get; }
    GPUMaker GPUMaker { get; }
    VideoCardMaker VideoCardMaker { get; }
    VideoCardMemoryMaker VideoMemoryMaker { get; }
    int VideoMemorySize { get; }
  }
}
