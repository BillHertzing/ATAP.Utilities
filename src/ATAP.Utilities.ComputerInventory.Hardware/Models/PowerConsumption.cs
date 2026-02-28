using System;
using System.Collections.Generic;

using UnitsNet;

namespace ATAP.Utilities.ComputerInventory.Hardware
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
  /*
public class PowerConsumptionConverter : ExpandableObjectConverter
{
  public override bool CanConvertFrom(
      ITypeDescriptorContext context, Type sourceType)
  {
    if (sourceType == typeof(string))
    {
      return true;
    }
    return base.CanConvertFrom(context, sourceType);
  }

  public override bool CanConvertTo(
      ITypeDescriptorContext context, Type destinationType)
  {
    if (destinationType == typeof(string))
    {
      return true;
    }
    return base.CanConvertTo(context, destinationType);
  }

  public override object ConvertFrom(ITypeDescriptorContext
      context, CultureInfo culture, object value)
  {
    if (value == null)
    {
      return new PowerConsumption();
    }

    if (value is string)
    {
      //ToDo better validation on string to be sure it conforms to  "double-TimeBlock"
      string[] s = ((string)value).Split('-');
      if (s.Length != 2 || !double.TryParse(s[0], out double w) || !TimeSpan.TryParse(s[1], out TimeSpan period))
      {
        throw new ArgumentException("Object is not a string of format double-int",
                                   "value");
      }

      return new PowerConsumption(w, period);
    }

    return base.ConvertFrom(context, culture, value);
  }

  public override object ConvertTo(
      ITypeDescriptorContext context,
      CultureInfo culture, object value, Type destinationType)
  {
    if (value != null)
    {
      if (!(value is PowerConsumption))
      {
        throw new ArgumentException("Invalid object, is not a PowerConsumption", "value");
      }
    }

    if (destinationType == typeof(string))
    {
      if (value == null)
      {
        return string.Empty;
      }

      PowerConsumption powerConsumption = (PowerConsumption)value;
      return powerConsumption.ToString();
    }
    return base.ConvertTo(context,
                          culture,
                          value,
        destinationType);
  }
}
*/

}
