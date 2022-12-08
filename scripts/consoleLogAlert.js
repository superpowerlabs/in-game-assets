const {execSync} = require("child_process");
const path = require("path");

function consoleLogAlert() {
  const result = execSync(`cd ${path.resolve(__dirname, "../contracts")} && grep -r 'import "hardhat' .`).toString();
  if (/:import/.test(result)) {
    throw new Error("At least a console.log has been left in the contracts");
  }
}

module.exports = consoleLogAlert;
