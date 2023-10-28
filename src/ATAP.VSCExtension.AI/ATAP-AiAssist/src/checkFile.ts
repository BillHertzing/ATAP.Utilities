import * as fs from 'fs';

export const checkFile = (path: string, mode: number): Promise<boolean> => {
  return new Promise((resolve, reject) => {
    fs.access(path, mode, (err) => {
      if (err) {
        reject(err);
      } else {
        resolve(true);
      }
    });
  });
};


