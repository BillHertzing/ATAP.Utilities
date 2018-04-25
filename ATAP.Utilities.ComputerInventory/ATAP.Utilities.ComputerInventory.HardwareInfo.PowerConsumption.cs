using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Globalization;
using System.Text;

namespace ATAP.Utilities.ComputerInventory
{
    public interface IPowerConsumption : IObservable<PowerConsumption>
    {
        TimeSpan Period { get; set; }
        double Watts { get; set; }
    }

    //ToDo make these thread-safe (concurrent)
    public class PowerConsumption : IPowerConsumption
    {
        TimeSpan period;
        double watts;

        public PowerConsumption()
        {
            this.watts = default;
            this.period = default;
        }
        public PowerConsumption(double w, TimeSpan period)
        {
            this.watts = w;
            this.period = period;
        }

        public override string ToString()
        {
            return $"{this.watts}-{this.period}";
        }

        public TimeSpan Period { get => period; set => period = value; }
        public double Watts { get => watts; set => watts = value; }

        public IDisposable Subscribe(IObserver<PowerConsumption> observer)
        {
            throw new NotImplementedException();
        }
    }
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



}
