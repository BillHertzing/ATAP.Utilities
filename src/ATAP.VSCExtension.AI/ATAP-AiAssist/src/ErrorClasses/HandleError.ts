import { DetailedError } from 'ErrorClasses/DetailedError';

/*
This function will be used to handle errors in the application.  It will be called from the catch block of a try/catch block.
This function never returns, it always throws an error.
*/
export function HandleError(e: any, className: string, methodName: string, data: string): never {
  if (e instanceof Error) {
    throw new DetailedError(`${className}=>${methodName}: failed on data: ${data} -> `, e);
  } else {
    // ToDo:  investigation to determine what else might happen
    throw new Error(
      `${className}=>${methodName}: failed on data: ${data} and the instance of (e) returned is of type ${typeof e}`,
    );
  }
}
