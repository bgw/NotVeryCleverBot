/**
 * Called at the entry-point of the application/gulp/mocha, and sets up all the
 * required polyfills for node/iojs.
 *
 * This may respawn node, so it *must come first*.
 *
 * This module must be written in such a way that it can be run on vanilla
 * node/iojs (without babel).
 */

if (typeof Proxy === 'undefined') {
  const spawnSync = require('child_process').spawnSync;
  const result = spawnSync(
    process.argv[0],
    ['--harmony-proxies'].concat(process.argv.slice(1)),
    {stdio: 'inherit'}
  );
  if (result.error) {
    throw result.error;
  }
  process.exit(result.status);
}

require('harmony-reflect');
require('babel/polyfill');
require('source-map-support/register');
