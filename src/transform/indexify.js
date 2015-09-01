import crypto from 'crypto';

import {default as normalize, VERSION as NORMALIZE_VERSION} from './normalize';
import Version from './Version';

// should get changed whenever the output might be modified
export const VERSION = new Version(
  {indexify: 0},
  NORMALIZE_VERSION
);

export default function indexify(str, digestEncoding='base64') {
  const hash = crypto.createHash('md5');
  hash.update(normalize(str), 'utf8');
  return hash.digest(digestEncoding);
}
