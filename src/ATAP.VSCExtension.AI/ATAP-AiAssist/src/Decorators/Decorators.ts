import { DetailedError } from '@ErrorClasses/index';
import { LogLevel, ILogger, Logger } from '@Logger/index';

// A method decorator that logs the entry into a synchronous method
export function logFunction(target: any, propertyKey: string, descriptor: PropertyDescriptor): PropertyDescriptor {
  const originalMethod = descriptor.value; // Save a reference to the original method
  console.log(`${propertyKey} Starting`);
  descriptor.value = function (...args: any[]) {
    const result = originalMethod.apply(this, args); // Call the original method
    console.log(`${propertyKey} Completed`);
    // Logger.staticLog(`staticLogger: ${propertyKey} executed in ${finish - start} milliseconds`, LogLevel.Debug); // ToDo: theser is a bug in the staticLogger logic
    return result; // Return the original method's return value
  };
  return descriptor; // Return the modified descriptor
}

// A method decorator that logs the entry into a synchronous method
export function logAsyncFunction(target: any, propertyKey: string, descriptor: PropertyDescriptor): PropertyDescriptor {
  const originalMethod = descriptor.value; // Save a reference to the original method
  console.log(`${propertyKey} Starting`);
  descriptor.value = async function (...args: any[]) {
    const result = await originalMethod.apply(this, args); // Call the original method
    console.log(`${propertyKey} Completed`);
    // Logger.staticLog(`staticLogger: ${propertyKey} executed in ${finish - start} milliseconds`, LogLevel.Debug); // ToDo: theser is a bug in the staticLogger logic
    return result; // Return the original method's return value
  };
  return descriptor; // Return the modified descriptor
}

// A method decorator that logs the execution time of the method
export function logExecutionTime(target: any, propertyKey: string, descriptor: PropertyDescriptor): PropertyDescriptor {
  const originalMethod = descriptor.value; // Save a reference to the original method

  descriptor.value = function (...args: any[]) {
    console.log(`${propertyKey} Starting`);
    const start = performance.now(); // Start timer
    const result = originalMethod.apply(this, args); // Call the original method
    const finish = performance.now(); // End timer
    console.log(`${propertyKey} Completed`);
    console.log(`${propertyKey} Executed in ${finish - start} milliseconds`);
    // Logger.staticLog(`staticLogger: ${propertyKey} executed in ${finish - start} milliseconds`, LogLevel.Debug); // ToDo: theser is a bug in the staticLogger logic
    return result; // Return the original method's return value
  };
  return descriptor; // Return the modified descriptor
}

export function logConstructor<T extends new (...args: any[]) => {}>(originalConstructor: T) {
  return class extends originalConstructor {
    constructor(...args: any[]) {
      console.log(`${originalConstructor.name}.ctor Starting `, LogLevel.Debug);
      super(...args);
      console.log(`${originalConstructor.name}.ctor Completed`, LogLevel.Debug);
      //Logger.staticLog(`A new instance of ${originalConstructor.name} was created!`, LogLevel.Debug);
    }
  };
}
