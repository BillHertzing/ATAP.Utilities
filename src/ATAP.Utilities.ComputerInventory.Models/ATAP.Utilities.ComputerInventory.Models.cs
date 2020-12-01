using System;
using ATAP.Utilities.ComputerInventory.Hardware;
using ATAP.Utilities.ComputerInventory.ProcessInfo;
using ATAP.Utilities.ComputerInventory.Software;

using System.Collections.Generic;
using ATAP.Utilities.ComputerInventory.Interfaces;

namespace ATAP.Utilities.ComputerInventory
{
  public class ComputerInventory : IEquatable<ComputerInventory>, IComputerInventory
  {
    public ComputerInventory()
    {
    }

    public ComputerInventory(IComputerHardware computerHardware, IComputerSoftware computerSoftware, IComputerProcesses computerProcesses)
    {
      ComputerHardware = computerHardware ?? throw new ArgumentNullException(nameof(computerHardware));
      ComputerSoftware = computerSoftware ?? throw new ArgumentNullException(nameof(computerSoftware));
      ComputerProcesses = computerProcesses ?? throw new ArgumentNullException(nameof(computerProcesses));
    }

    public IComputerHardware ComputerHardware { get; }
    public IComputerSoftware ComputerSoftware { get; }
    public IComputerProcesses ComputerProcesses { get; }

    public override bool Equals(object obj)
    {
      return Equals(obj as ComputerInventory);
    }

    public bool Equals(ComputerInventory other)
    {
      
      throw new NotImplementedException();
      //ToDo: Figure out Equality and GetHashCode
      /*
      return other != null &&
             EqualityComparer<ComputerHardware>.Default.Equals(ComputerHardware, other.ComputerHardware) &&
             EqualityComparer<ComputerSoftware>.Default.Equals(ComputerSoftware, other.ComputerSoftware) &&
             EqualityComparer<ComputerProcesses>.Default.Equals(ComputerProcesses, other.ComputerProcesses);
             */
    }

    public override int GetHashCode()
    {
      throw new NotImplementedException();
      //ToDo: Figure out Equality and GetHashCode
      /*
      var hashCode = 1714258590;
      hashCode = hashCode * -1521134295 + EqualityComparer<ComputerHardware>.Default.GetHashCode(ComputerHardware);
      hashCode = hashCode * -1521134295 + EqualityComparer<ComputerSoftware>.Default.GetHashCode(ComputerSoftware);
      hashCode = hashCode * -1521134295 + EqualityComparer<ComputerProcesses>.Default.GetHashCode(ComputerProcesses);
      return hashCode;
      */
    }

    public static bool operator ==(ComputerInventory left, ComputerInventory right)
    {
      return EqualityComparer<ComputerInventory>.Default.Equals(left, right);
    }

    public static bool operator !=(ComputerInventory left, ComputerInventory right)
    {
      return !(left == right);
    }

    // The IObservable provider objects, classes, and methods
    // attribution:  https://docs.microsoft.com/en-us/dotnet/standard/events/how-to-implement-a-provider
    List<IObserver<IComputerInventory>> Observers { get; }
    private class Unsubscriber : IDisposable
    {
      List<IObserver<IComputerInventory>> Observers { get; }
      private IObserver<IComputerInventory> Observer { get; }

      public Unsubscriber(List<IObserver<IComputerInventory>> observers, IObserver<IComputerInventory> observer)
      {
        Observers = observers ?? throw new ArgumentNullException(nameof(observers));
        Observer = observer ?? throw new ArgumentNullException(nameof(observer));
      }

      public void Dispose()
      {
        if (!(Observer == null))
        {
          Observers.Remove(Observer);
        }
      }
    }

    public IDisposable Subscribe(IObserver<IComputerInventory> observer)
    {
      if (!Observers.Contains(observer))
      {
        Observers.Add(observer);
      }

      return new Unsubscriber(Observers, observer);
    }
    public void NotifyObservers()
    {
      //ToDo implement the method that gets a ComputerInventory instance update
      throw new NotImplementedException();
      //foreach (var observer in observers)
      //  observer.OnNext(tempAndFanData); // An event should trigger this, and pass in a TempAndFan instance named tempAndFanData
      //}
      //foreach (var observer in observers.ToArray())
      //if (observer != null) observer.OnCompleted(); // this is the code to use if the instance will never send data again
      //}
      //observers.Clear();
    }

  }
}
