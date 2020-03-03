using System;
using System.Collections.Generic;
using ATAP.Utilities.ComputerInventory.Interfaces.Hardware;
using UnitsNet;

namespace ATAP.Utilities.ComputerInventory.Models.Hardware
{
  //ToDo make these thread-safe (concurrent)
  [Serializable]
  public class PowerConsumption : IPowerConsumption, IEquatable<PowerConsumption>
  {
    public PowerConsumption()
    {
    }

    public PowerConsumption(TimeSpan timeSpan, Power power)
    {
      TimeSpan = timeSpan;
      Power = power;
    }

    public TimeSpan TimeSpan { get; }
    public UnitsNet.Power Power { get; }

    public override bool Equals(object obj)
    {
      return Equals(obj as PowerConsumption);
    }

    public bool Equals(PowerConsumption other)
    {
      return other != null &&
             TimeSpan.Equals(other.TimeSpan) &&
             Power.Equals(other.Power);
    }

    public override int GetHashCode()
    {
      var hashCode = 1034165858;
      hashCode = hashCode * -1521134295 + TimeSpan.GetHashCode();
      hashCode = hashCode * -1521134295 + Power.GetHashCode();
      return hashCode;
    }

    public static bool operator ==(PowerConsumption left, PowerConsumption right)
    {
      return EqualityComparer<PowerConsumption>.Default.Equals(left, right);
    }

    public static bool operator !=(PowerConsumption left, PowerConsumption right)
    {
      return !(left == right);
    }
  }
}
