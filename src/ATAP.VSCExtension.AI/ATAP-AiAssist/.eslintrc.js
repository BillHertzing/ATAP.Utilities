module.exports = {
    root: true,
    parser: "@typescript-eslint/parser",
    parserOptions: {
        ecmaVersion: 6,
        sourceType: "module"
    },
    plugins: [
        "@typescript-eslint"
    ],
    rules: {
        "@typescript-eslint/naming-convention": [
            "error",
            {
                selector: "enumMember",
                format: ["StrictPascalCase"]
            }
        ],
        "@typescript-eslint/semi": "warn",
        "curly": "warn",
        "eqeqeq": "warn",
        "no-throw-literal": "warn",
        "semi": "off"
    },
    ignorePatterns: [
        "out",
        "dist",
        "**/*.d.ts"
    ]
};