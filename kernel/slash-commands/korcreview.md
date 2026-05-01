---
name: korcreview
description: Run ORC-specific Linux kernel regression review
argument-hint: [commit|range|patch]
---

Read the prompt {{REVIEW_DIR}}/agent/orc.md

If a git range is provided, it's meant for the false-positive-guide.md section

Using the prompt, do a deep dive regression analysis of the top commit, or the provided patch/commit
