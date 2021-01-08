using System;

namespace ATAP.Utilities.TypedGuids {
  //Attribution: taken from answers provided to this question: https://stackoverflow.com/questions/53748675/strongly-typed-guid-as-generic-struct
  // Modifications:  CheckValue and all references removed, because our use case requires Guid.Empty to be a valid value
  public struct Id<T> : IEquatable<Id<T>>, IId<T> {
    private readonly Guid _value;

    public Id(string value) {
      bool success;
      string iValue;
      if (string.IsNullOrEmpty(value)) {
        _value = Guid.NewGuid();
      }
      else {
        // Hack, used because only ServiceStack Json serializers add extra enclosing ".
        //  but, neither simpleJson nor NewtonSoft will serialize this at all
        iValue = value.Trim('"');
        success = Guid.TryParse(iValue, out Guid newValue);
        if (!success) { throw new NotSupportedException($"Guid.TryParse failed, value {value} cannot be parsed as a GUID"); }
        _value = newValue;
      }
    }

    public Id(Guid value) {
      _value = value;
    }

    public override bool Equals(object obj) {
      return obj is Id<T> id && Equals(id);
    }

    public bool Equals(Id<T> other) {
      return _value.Equals(other._value);
    }

    public override int GetHashCode() => _value.GetHashCode();

    public override string ToString() {
      return _value.ToString();
    }

    public static bool operator ==(Id<T> left, Id<T> right) {
      return left.Equals(right);
    }

    public static bool operator !=(Id<T> left, Id<T> right) {
      return !(left == right);
    }
  }
}
