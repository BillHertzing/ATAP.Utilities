

namespace ATAP.Utilities.ComputerInventory.Hardware
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
