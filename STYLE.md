# Style guide

These rules apply to every file in the course, except the files in `archive/`, which are kept unchanged until they are reworked.

## Writing

- English with UK spelling (colour, behaviour, organise, licence as a noun) and metric units.
- Headings in sentence case: only the first word and proper nouns take a capital letter.
- No em dashes and no en dashes. Use a full stop, a comma, a colon or parentheses.
- No semicolons in prose.
- No bold inside sentences. Bold is not used for emphasis anywhere.
- No "eg" in brackets. Write "for example".
- Avoid filler words such as robust, seamless, tailored, foster, genuinely, leverage, crucial and delve.
- In bulleted lists, write natural sentences, not "Title: content".
- Explain every container and Kubernetes term the first time a chapter uses it. Do not explain Azure basics. Link to Microsoft Learn instead.
- Paraphrase documentation and link to it. Do not copy documentation text.
- Every product fact, limit and price is checked against primary documentation and cited in the Sources section of the chapter. Write "not verified" next to a statement that could not be checked.
- Prices name their source, the currency, the region and the date of the lookup.
- No file mentions a real person, an employer or a client. The learner, the subscription and the region are always variables.

## Chapter structure

Each chapter `README.md` has these sections, in this order:

1. What you will be able to do: 3 to 5 observable outcomes.
2. Before you start: prerequisites, time needed, estimated cost of the lab.
3. Concepts: short sections, one Mermaid diagram where it helps. Each section ends with a check-yourself question whose answer sits in a `<details>` block.
4. Knowledge check: 5 multiple-choice questions. Answers and explanations go in `knowledge-check-answers.md`.
5. Lab: goal, acceptance criteria, how to run setup, validate and teardown, and what to do with the review prompt.
6. Clean up and cost check.
7. Sources, with links to primary documentation.

The chapter text never contains a copy-paste solution to the lab. Reference solutions live in `solutions/`.

## Labs

Every lab has five parts: `setup.sh`, a task with acceptance criteria in the README, `validate.sh`, `review-prompt.md` and `teardown.sh`.

## Scripts

- Bash, starting with `set -euo pipefail`.
- Every parameter comes from `.env` through `load_env` in `scripts/lib.sh`. Nothing is hard-coded per learner.
- Safe to run twice: a second run updates or skips, it never fails because something already exists.
- Validation scripts are strictly read-only. They print `[PASS]`, `[FAIL]` or `[WARN]` per check, with a hint after each failure, and exit with 0 when nothing fails and 1 otherwise.
- Scripts never print tokens, keys or passwords, and never take a password on the command line.
- SSH keys are created on the learner's computer and never written to the repository.

## Azure resources

- Every resource created by Bicep or by a script carries the tags `course=aro-k8s` and `chapter=NN`, where `NN` is the two-digit chapter number.
- A resource type that cannot carry tags (budgets, role assignments) is preceded in Bicep by a comment that starts with `// untaggable:` and says why.
- Teardown scripts end by listing everything still tagged `course=aro-k8s`.

## Files that must stay free of personal data

No file contains a subscription ID, a tenant ID, a public IP address, an e-mail address or a secret. Private address ranges (for example `10.20.0.0/16`) and the IDs of Azure built-in roles are allowed, because they are the same for everyone.

## Checks

Run these from the course root before publishing a change:

```bash
shellcheck scripts/*.sh chapters/*/lab/*.sh
for f in $(find chapters -name '*.bicep'); do az bicep build --file "$f" --stdout > /dev/null; done
npx markdownlint-cli2 "**/*.md"
python3 scripts/check-course.py
```

`scripts/check-course.py` checks the writing rules, the internal links, the tags and the personal data rules above. To also search for names that must never appear (your own name, an employer, a client), put them in the `PRIVATE_TERMS` environment variable, separated by commas. Never write them in a file of the course.
