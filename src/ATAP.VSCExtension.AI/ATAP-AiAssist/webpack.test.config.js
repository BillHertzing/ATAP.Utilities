import { dirname, resolve } from "path";
import * as webpack from "webpack";
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

export default {
  mode: "development", // development mode for better source maps
  entry: "./src/test/runTests.ts",
  output: {
    filename: "tests.bundle.js",
    // the bundle is stored in the '_generated/tests' folder (check package.json), 📖 -> https://webpack.js.org/configuration/output/
    path: resolve(__dirname, "_generated/tests"),
  },

  module: {
    rules: [
      {
        test: /\.ts$/,
        exclude: [/node_modules/],
        use: [
          {
            loader: "ts-loader",
            options: {
              // to speed up build times, we can use transpileOnly mode
              transpileOnly: true,
              //experimentalFileCaching: true,
              //cacheDirectory: resolve(dirname(fileURLToPath(import.meta.url)), ".cache"),
            },
          },
        ],
      },
      {
        test: /\.mjs$/,
        include: /node_modules/,
        type: "javascript/auto",
      },
      {
        test: /\.js$/,
        use: "source-map-loader",
        enforce: "pre",
      },
    ],
  },
  devtool: "source-map",
  infrastructureLogging: {
    level: "log", // enables logging required for problem matchers
  },
  resolve: {
    extensions: [".ts", ".js"],
    fallback: {
      child_process: false, // Assuming you don't need a polyfill for this in tests
      fs: false, // Assuming you don't need a polyfill for this in tests
      os: require.resolve("os-browserify/browser"),
      path: require.resolve("path-browserify"),
      util: require.resolve("util/"),
      net: false, // Assuming you don't need a polyfill for this in tests
      tls: false, // Assuming you don't need a polyfill for this in tests
      url: require.resolve("url/"),
      assert: require.resolve("assert/"),
      stream: require.resolve("stream-browserify"),
      // ... other necessary fallbacks ...
    },
  },
  // Add other necessary configurations
};
