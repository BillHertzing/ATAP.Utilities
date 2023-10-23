"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
class StringBuilder {
    constructor() {
        this._textArray = [];
    }
    append(text) {
        this._textArray.push(text);
    }
    toString() {
        return this._textArray.join('');
    }
}
exports.default = StringBuilder;
//# sourceMappingURL=StringBuilder.js.map