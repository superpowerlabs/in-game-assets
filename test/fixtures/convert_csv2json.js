const fs = require("fs");
const path = require("path");
const {parse} = require("csv-parse/sync");

const dir = fs.readdirSync(path.resolve(__dirname, "csv"));
for (let f of dir) {
  if (/\.csv$/.test(f)) {
    let data = fs.readFileSync(path.resolve(__dirname, "csv", f), "utf8");
    data = parse(data, {columns: true});
    data = data.map((e) => {
      for (let key in e) {
        if (/^\d+$/.test(e[key])) {
          e[key] = parseInt(e[key]);
        }
      }
      return e;
    });
    fs.writeFileSync(path.resolve(__dirname, "json", f.replace(/csv$/, "json")), JSON.stringify(data, null, 2));
  }
}
