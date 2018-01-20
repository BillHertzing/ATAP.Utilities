using System;

namespace ATAP.Utilities.ComputerInventory
{
    public interface ITempAndFan 
    {
        double FanPct { get; set; }
        double Temp { get; set; }
        //IDisposable Subscribe(IObserver<TempAndFan> observer);

    }

    //ToDo make these thread-safe (concurrent)
    public class TempAndFan : ITempAndFan 
    {

        public double Temp { get; set; }
        public double FanPct { get; set; }
        public IDisposable Subscribe(IObserver<TempAndFan> observer)
        {
            throw new NotImplementedException();
        }

    }
}