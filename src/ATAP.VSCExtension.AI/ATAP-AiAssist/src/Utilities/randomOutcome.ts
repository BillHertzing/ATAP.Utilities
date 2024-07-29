// *********************************************************************************************************************
export function randomOutcome(
  strToReturn: string,
): Promise<{ isCancelled: boolean; result: string | undefined }> {
  return new Promise((resolve, reject) => {
    setTimeout(() => {
      // Add a 1-second (1000 milliseconds) delay
      const randomNumber = Math.random();

      if (randomNumber < 0.33) {
        // 33% chance to resolve with "TaskSucceeded"
        resolve({ isCancelled: false, result: strToReturn });
      } else if (randomNumber >= 0.33 && randomNumber < 0.66) {
        // Additional 33% chance to resolve with isCancelled = true
        resolve({ result: undefined, isCancelled: true });
      } else {
        // Remaining 34% chance to throw an error
        reject(new Error("An error occurred"));
      }
    }, 1000); // Delay specified here
  });
}
