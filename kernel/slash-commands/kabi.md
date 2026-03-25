---
name: kabi
description: Perform a user/kernel ABI compatibility review of a Linux kernel patch
argument-hint: [commit|range]
---

Perform a user/kernel ABI compatibility review of a Linux kernel patch.

## Setup

1. This command must run with a Linux kernel tree as the working
   directory. Confirm that `Documentation/ABI/README` exists; if it
   does not, stop and tell the user to run /kabi from inside a
   kernel tree.
2. Read {{REVIEW_DIR}}/abi-review.md
   and follow the protocol defined there.
3. The patch under review is specified by the argument: $ARGUMENTS.
   This is a git ref (commit hash, range, or symbolic ref like HEAD).
   If no argument is given, review HEAD.
