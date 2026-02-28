using Itenso.TimePeriod;
using System;
using UnitsNet;

namespace ATAP.Utilities.ComputerInventory.Hardware
{
  public interface IPowerConsumption
  {
    Power Power { get; }
    TimeSpan TimeSpan { get; }
  }

}
