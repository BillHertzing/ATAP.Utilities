import { DetailedError } from '@ErrorClasses/index';
import { LogLevel, ILogger, Logger } from '@Logger/index';


// A method decorator that logs the execution time of the method
export function logExecutionTime(target: any, propertyKey: string, descriptor: PropertyDescriptor): PropertyDescriptor {
  const originalMethod = descriptor.value; // Save a reference to the original method

  descriptor.value = function (...args: any[]) {
    const start = performance.now(); // Start timer
    const result = originalMethod.apply(this, args); // Call the original method
    const finish = performance.now(); // End timer

    console.log(`${propertyKey} executed in ${finish - start} milliseconds`);
    return result; // Return the original method's return value
  };

  return descriptor; // Return the modified descriptor
}

export function logConstructor<T extends new(...args: any[]) => {}>(originalConstructor: T) {
  return class extends originalConstructor {
      constructor(...args: any[]) {
          super(...args);
          //Logger.staticLog(`A new instance of ${originalConstructor.name} was created!`, LogLevel.Debug);
      }
  };
}
