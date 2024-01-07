export class StringBuilder {
  private _textArray: string[] = [];

  append(text: string): void {
    this._textArray.push(text);
  }

  toString(): string {
    return this._textArray.join('');
  }
}
