module.exports = {
  env: {
    browser: false,
    es2021: true,
    mocha: true,
    node: true,
  },
  extends: ["standard", "plugin:prettier/recommended"],
  parserOptions: {
    ecmaVersion: 12,
  },
  overrides: [
    {
      files: ["hardhat.config.js"],
      globals: { task: true },
    },
  ],
  rules: {
    eqeqeq: "off",
    "no-unused-vars": "off",
    "no-undef": "off",
    "prefer-const": "warn",
    "no-unused-expressions": "warn",
  },
};
