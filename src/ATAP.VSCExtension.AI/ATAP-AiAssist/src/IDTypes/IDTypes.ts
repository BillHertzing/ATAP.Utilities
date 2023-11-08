import { generateGuid } from '@Utilities/index';

export type GUID = string; // retaining these in the hope that someday will be able to make IDType either and Int or a GUID
export type Int = number;
export type IDType = GUID; // GUID | Int; // No longer supports generic type on Philote

export function nextID(): IDType {
    return generateGuid();

}
