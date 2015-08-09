// Every reddit "thing" has a "name" (sometimes called a "fullname") associated
// with it. This has a typecode, followed by the thing's id.
export function typedName(typeNumber) {
  return new RegExp(`t${typeNumber}_[a-z0-9]+`);
}

// Different versions of `typedName`
export let name = typedName('[0-9]+');
export let commentName = typedName(1);
export let accountName = typedName(2);
export let articleName = typedName(3);
export let linkName = typedName(3);
export let messageName = typedName(4);
export let subredditName = typedName(5);
export let awardName = typedName(6);
export let promoCampaignName = typedName(8);

export function json(str) {
  try {
    JSON.parse(str);
    return true;
  } catch (err) {
    return false;
  }
}
