// We theorize (completely made up number) that parent comments create half the
// value of the child comment, we can normalize them this way.
//
// Unfortunately there's no magic solution to this, but we need some way to
// compensate for a great child comment under an low-voted parent comment vs a
// poor child comment under a high-voted parent comment.
//
// As time goes on, we can experiment with different scoring functions.
//
// This expects a database object (not a raw reddit json object)

export function getNormalizedScore(comment, parent) {
  parentScore = parent != null ? parent.score : comment.parentCommentScore;
  if (parentScore != null) {
    return comment.score - parentScore / 2;
  } else {
    return comment.score / 2; // shitty approximation
  }
}
