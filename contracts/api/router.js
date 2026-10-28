const { createApp } = require("../lib/router.cjs");
const { getReadyDb } = require("../lib/db.cjs");

module.exports = createApp({ getDb: getReadyDb });
