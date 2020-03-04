using ATAP.Utilities.ComputerInventory.Enumerations;

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
