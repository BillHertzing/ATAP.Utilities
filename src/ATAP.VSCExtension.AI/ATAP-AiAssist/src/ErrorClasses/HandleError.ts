import { DetailedError } from 'ErrorClasses/DetailedError';

export function HandleError(e: any, className: String, methodName: string, data: string): void {
  if (e instanceof Error) {
    throw new DetailedError(`className methodName: failed to write ${data} -> `, e);
  } else {
    // ToDo:  investigation to determine what else might happen
    throw new Error(
      `className methodName: failed to write ${data} and the instance of (e) returned is of type ${typeof e}`,
    );
  }
}
