// ToDo: make this a service for handing out ID

export function generateGuid(): string {
  return 'xxxxxxxx-xxxx-4xxx-xxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
    const r = (Math.random() * 16) | 0,
      v = c === 'x' ? r : (r & 0x3) | 0x8;
    return v.toString(16);
  });
}
// retaining these in the hope that someday will be able to make IDType either an Int or a GUID
// export function generateNextInt(): number {
//   // ToDo: use a sequence, keep track of last used, supply the next in sequence
//   // ToDo: considerations for loading sequence and last used from persistence
//   //ToDo: replace Random number generator
//   return (Math.random() * 4098);
// }

