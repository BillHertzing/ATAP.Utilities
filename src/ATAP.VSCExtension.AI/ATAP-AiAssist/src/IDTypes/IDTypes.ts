import { generateGuid, generateNextInt } from '@Utilities/index';

export type GUID = string;
export type Int = number;
export type IDType = GUID | Int;

export function nextID<T extends IDType>(type: "GUID" | "Int"): T {
  if (type === "GUID") {
    return generateGuid() as T;
  } else if (type === "Int") {
    return generateNextInt() as T;
  }

  throw new Error("Unsupported ID type"); // Handle case where type is neither GUID nor Int
}
