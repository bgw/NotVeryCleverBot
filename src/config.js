import _ from 'lodash';
import fs from 'fs';
import inquirer from 'inquirer';
import knex from 'knex';
import program from 'commander';
import Promise from 'bluebird';
import yaml from 'js-yaml';
import {version} from '../package.json';

const config = Object.assign({},
  yaml.load(fs.readFileSync('./config.yaml'), {filename: './config.yaml'})
);

export default config;

/**
 * Pulls in command-line arguments and interactively prompts the user if there's
 * missing information for certain fields.
 *
 * You may be able to consume config before init is called, but know that some
 * fields may not be complete.
 */
config.init = async function init() {
  program
    .version(version)
    .option('-u, --username [name]', "Username of bot's reddit account")
    .option('-o, --owner [name]', 'Your username')
    .option('-n, --botname [name]', "Bot's name for the useragent string")
    .parse(process.argv);

  Object.assign(config, _.pick(program, 'username', 'owner', 'botname'));
  let answers = await new Promise((resolve, _reject) => {
    inquirer.prompt([
      {
        name: 'username',
        type: 'input',
        message: 'Reddit account username',
        when: () => config.username == null,
      },
      {
        name: 'password',
        type: 'password',
        message: 'Reddit account password',
        when: () => config.password == null,
      },
    ], resolve);
  });
  Object.assign(config, answers);

  config.knex = knex(config.database);

  return config;
}
