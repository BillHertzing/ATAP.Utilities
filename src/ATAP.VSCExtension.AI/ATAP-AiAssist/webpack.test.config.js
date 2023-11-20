const path = require('path');
const webpack = require('webpack');

module.exports = {
    mode: 'development', // development mode for better source maps
    entry: './src/test/runTest.ts',
    devtool: 'inline-source-map', // Important for debugging
    module: {
        rules: [
            {
                test: /\.ts$/,
                use: 'ts-loader',
                exclude: /node_modules/
            },
            {
                test: /\.js$/,
                use: "source-map-loader",
                enforce: "pre"
            }
        ]
    },
    resolve: {
        extensions: ['.ts', '.js'],
        fallback: {
            "child_process": false, // Assuming you don't need a polyfill for this in tests
            "fs": false, // Assuming you don't need a polyfill for this in tests
            "os": require.resolve("os-browserify/browser"),
            "path": require.resolve("path-browserify"),
            "util": require.resolve("util/"),
            "net": false, // Assuming you don't need a polyfill for this in tests
            "tls": false, // Assuming you don't need a polyfill for this in tests
            "url": require.resolve("url/"),
            "assert": require.resolve("assert/"),
            "stream": require.resolve("stream-browserify"),
            // ... other necessary fallbacks ...
        }
    },
    output: {
        filename: 'tests.bundle.js',
        path: path.resolve(__dirname, '_generated/tests')
    },
    // Add other necessary configurations
};
