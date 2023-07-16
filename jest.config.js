const { jestConfig } = require("@salesforce/sfdx-lwc-jest/config");

module.exports = {
  ...jestConfig,
  moduleNameMapper: {
    "^lightning/platformShowToastEvent$":
      "<rootDir>/force-app/test/Jest-mocks/lightning/platformShowToastEvent",
    "^lightning/input$": "<rootDir>/force-app/test/Jest-mocks/lightning/input",
    "^lightning/navigation$": "<rootDir>/force-app/test/Jest-mocks/lightning/navigation"
  },
  modulePathIgnorePatterns: ["<rootDir>/.localdevserver"]
};
