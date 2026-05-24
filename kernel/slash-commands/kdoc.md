---
name: kdoc
description: Perform a documentation-focused review of a Linux kernel patch
argument-hint: [commit|range|patch]
---

Perform a documentation-focused review of a Linux kernel patch.

## Setup

1. Load the /kernel skill. This is a documentation review only:
   do not run the review-core.md regression protocol, and report
   in the format given in the Output section below.
2. The argument $ARGUMENTS selects the patch. Resolve it in this
   order: (a) if it names an existing file, read it as a patch or
   mbox (split an mbox on `^From ` lines and review each message
   as a separate patch); (b) if `git rev-parse --verify -q
   '$ARGUMENTS^{commit}'` succeeds, it is a single commit; (c) if
   it contains `..`, it is a range: list the commits with
   `git rev-list --reverse <range>` and review each one separately,
   repeating every section below per commit; (d) otherwise try
   `stg id '$ARGUMENTS'` and use the resulting hash. If no argument
   is given, review HEAD.
3. For each commit, read the full diff (`git show <hash>`) and
   commit message (`git log --format=%B -1 <hash>`) before
   producing any findings.

## Verify claims

Before checking style or formatting, verify the factual claims
made by the commit message and code comments against the code.
For each claim, locate the code it is about. If that code is in
the diff, trace it there. If the claim concerns code outside the
diff (callers, a lock the code holds, behavior of the commit named
in a Fixes: tag), read that code with `git show <hash>:<path>` or
find the callers with grep before judging. Flag a claim only when
the code you read contradicts it, not because the diff alone does
not contain the evidence. If you cannot locate the relevant code,
say so and do not label the claim either way.

## Prose checks

These apply to the commit message and to code comments alike.

- Component as subject, not "we." Describe mechanism and
  causation, not what code "does," "wants," or "tries to do."
- Short declarative sentences, one causal link each: "so" or
  "because" spent once, and no aside hung on a sentence that
  already carries one. Two links in a sentence is a run-on.
- Terms come from the subsystem -- identifiers in the code, or
  vocabulary its own list traffic uses. Flag an abstraction
  coined to sound precise; name the words the subsystem uses
  instead.
- No deriving the subsystem's mechanics for the people who
  maintain it. State the change and the constraint it operates
  under. A derivation of machinery the reader wrote is padding,
  and it is where an error gets answered instead of the patch.
- Preserve domain-specific terms ("quiesce" is not "stop,"
  "elide" is not "skip").
- No hidden-baseline adjectives (generous, conservative,
  sufficient, defensive -- test: "[adjective] compared to what?").
- Cut filler that carries no information: "it's worth noting,"
  "essentially," "importantly," "in order to." No
  anthropomorphizing, no hedging.
- ASCII only: no em dashes or smart quotes.

## Commit message review

- The subject line accurately describes the change in the diff.
- The body opens with why the change is necessary, not what it does.
- The body uses flowing prose, not bullet lists.
- The body earns its length. Two paragraphs -- why, then what -- is
  the common shape; flag a third that answers no question the code
  raises, and any sentence that survives only because it is true.
- No enumeration of what the patch adds. A bullet per added test,
  or a paragraph per new function, restates the diff.
- No development history: "now," "previously," "instead of the
  earlier approach," or a defense of the design against an
  alternative raised in review. Version-to-version changes belong
  in the changelog, reviewer-facing commentary below the "---".
- For bug fixes, a Fixes: tag is present and names the commit that
  introduced the bug: verify per {{REVIEW_DIR}}/fixes-tag.md (the
  tag format, and that the cited commit touches the code being
  fixed).
- No body line exceeds 72 columns. Test:
  `git log --format=%B -1 <hash> | awk 'length > 72'`; every line
  printed is a finding, except trailer lines (Fixes:, Link:,
  Signed-off-by:, URLs), which are not wrapped.

## Code comment review

For each comment on a `+` line of the diff (added or modified by
the patch):

- The comment is factually accurate relative to the surrounding code.
- The comment earns its place: something is lost if it is deleted.
  One that restates the line below it, captions a block, or
  narrates mechanism the code already shows is a finding.
- The fact is not already recorded where a reader would look --
  the header, the struct definition, the caller, the callee, or an
  earlier comment in the same file. Check outside the diff: a
  comment duplicating unchanged code passes every check made
  within the patch.
- The comment explains WHY, not WHAT (the code shows what).
- Block length is earned by content that cannot compress. Flag a
  paragraph that could be three lines.
- Kernel-doc comments (`/** */`) use correct `@param:` and
  `Return:` syntax. Validate with `scripts/kernel-doc -Wall -none
  <file>` on each file containing modified kernel-doc comments.
  Run it against the post-patch file: when <hash> is not HEAD,
  write `git show <hash>:<file>` to the scratchpad and check that
  copy, since the worktree file may differ. Judge these by
  completeness, not by whether deleting them loses anything.
- No added line, with tabs expanded to 8 columns, exceeds 80
  columns. Test:
  `git show <hash> | grep '^+' | grep -v '^+++' | expand -t8 | awk 'length > 81'`
  (the 81 accounts for the leading `+`). The comment text width
  depends on indentation; do not apply a fixed column count.

Identify unchanged comments within the same function or struct
definition that a hunk modifies which the patch makes stale:
descriptions of behavior the patch alters, parameter names that
no longer match, return-value or error-path descriptions that no
longer apply, or assumptions the patch invalidates. Flag each as
a finding.

## Documentation review

Skip this section if the diff does not touch `Documentation/`.

For each new or modified file under `Documentation/`:

- Content is accurate relative to the code it describes.
- RST syntax is valid. Check with `make SPHINXOPTS=-W htmldocs`
  if the change is non-trivial.
- Cross-references to other documentation or code symbols resolve.

## Output

Report findings as a list. For each finding, state:
- File and line (or "commit message").
- What the problem is.
- Evidence: the code or text you checked that establishes the
  problem. Report only findings you confirmed; if you could not
  confirm one, omit it or list it under a separate "Unverified"
  heading with what would settle it.
- A suggested fix, or the corrected text.

If no issues are found in a section, state that explicitly.
Do not rewrite anything that is correct.
