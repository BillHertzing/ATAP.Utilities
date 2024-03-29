using System;
using System.ComponentModel;
using System.Linq;
using System.Reflection;
using System.Resources;

namespace ATAP.Utilities.Enumeration {

    ///ToDO: localize the application using satellite assemblies for specific languages
    public class LocalizedDescriptionAttribute : DescriptionAttribute
    {
        private readonly string _resourceKey;
        private readonly ResourceManager _resource;
        public LocalizedDescriptionAttribute(string resourceKey, Type resourceType)
        {
            _resource = new ResourceManager(resourceType);
            _resourceKey = resourceKey;
        }

        public override string Description{
            get {
                string displayName = _resource.GetString(_resourceKey);
                return string.IsNullOrEmpty(displayName)
                ? string.Format("[[{0}]]", _resourceKey)
                : displayName;
            }
        }
    }

    public static class Utilities {
        public static CustomAttributeType GetAttributeValue<CustomAttributeName, CustomAttributeType>(this Enum value) {
            // The enumeration value passed as the parameter to the GetSymbol method call
            var x = value
                // Get the the specific enumeration type
                .GetType()
                // Gets the FieldInfo object for this specific  value of the enumeration
                .GetField(value.ToString())
                // If the field info object is not null, get a custom attribute of type T from this specific value of the enumeration
                ?.GetCustomAttributes(typeof(CustomAttributeName), false)
                .FirstOrDefault();
                // If the result is not null, return it as CustomAttributeType, else return the default value for that CustomAttributeType
                if(x == null) {
                    return default(CustomAttributeType);
                }
            IAttribute<CustomAttributeType> z = x as IAttribute<CustomAttributeType>;
            return z.Value;
        }

        // The C# V6 way...
        public static string GetDescription(Enum value) {
            return
                value
                    .GetType()
                    .GetMember(value.ToString())
                    .FirstOrDefault()
                    ?.GetCustomAttribute<DescriptionAttribute>()
                    ?.Description;
        }

        public interface IAttribute<out T> {
            T Value { get; }
        }

        public static T ToEnum<T>(this string value, bool ignoreCase = true)
        {

                return (T)Enum.Parse(typeof(T), value, ignoreCase);
           
        }
    }
}
