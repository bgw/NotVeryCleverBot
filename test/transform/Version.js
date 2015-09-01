import {expect} from 'chai';

import Version from '../../dist/transform/Version';

describe('Version', () => {
  it('can be constructed with no dependencies', () => {
    new Version({foo: 5, bar: '0.0.1-baz'});
  });
  it('exposes the passed properties', () => {
    expect(new Version({foo: 5}).foo).to.equal(5);
  });
  it('can be constructed with a dependency', () => {
    const dep = new Version({});
    const dep2 = new Version({}, dep);
    new Version({}, dep, dep2);
  });
  it("exposes the dependency's properties", () => {
    const dep = new Version({foo: 1});
    const version = new Version({bar: 2}, dep);
    expect(version.foo).to.equal(1);
    expect(version.bar).to.equal(2);
  });
  describe('equals', () => {
    it('works on identity', () => {
      const v = new Version({});
      expect(v.equals(v)).to.be.true;
    });
    it('works on deeply equal objects', () => {
      const v1 = new Version({foo: {bar: 5}});
      const v2 = new Version({foo: {bar: 5}});
      expect(v1.equals(v2)).to.be.true;
      expect(v2.equals(v1)).to.be.true;
    });
    it('works on deeply non-equal objects', () => {
      const v1 = new Version({foo: {bar: 5}});
      const v2 = new Version({foo: {bar: '5'}});
      expect(v1.equals(v2)).to.be.false;
      expect(v2.equals(v1)).to.be.false;
    });
  });
});
