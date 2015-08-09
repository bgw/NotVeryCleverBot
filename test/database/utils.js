import knexModule from 'knex';
import chai from 'chai';
import chaiAsPromised from 'chai-as-promised';
chai.use(chaiAsPromised);

export let knex;

beforeEach(() => {
  knex = knexModule({
    dialect: 'sqlite3',
    connection: {
      filename: ':memory:',
    }
  });
});

afterEach(() => knex.destroy());
