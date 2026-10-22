# Writing a brief for Codex

The brief is the request part of the prompt; `codex-job` adds the mode's rules before it and,
for reviews, the output format after it. Write it to a file and pass `--prompt FILE`.

## Review and adversarial review

```markdown
Review the change on branch `fix/token-refresh` in /abs/repo: `git diff main...HEAD`.

What it does: refreshes the OAuth token before it expires instead of after a 401.
Already checked: unit tests pass; I read the refresh path once.

Read: src/auth/session.py, src/auth/refresh.py, tests/auth/test_refresh.py, and anything
that calls `Session.token`.

Questions:
1. Can two requests refresh at the same time and one of them use a revoked token?
2. What happens when the refresh call itself times out?
3. Is the 60-second margin safe with the clock skew we allow in config/auth.yaml?
```

- One change per review. Two unrelated changes get two jobs.
- Name the risks you worry about; Codex then digs there instead of skimming everything.
- Say what was already checked so it does not spend its time repeating it.
- For a plan or document, give its path and the code it describes.
- Adversarial mode: add what would make this expensive to get wrong (data loss, money,
  safety, a migration that cannot be undone). It is built to argue against shipping.

## Task

```markdown
In /abs/worktree, add retry with exponential backoff to `fetch_prices()` in
src/prices/client.py: 3 attempts, 0.5 s base, retry only on timeouts and HTTP 5xx.

Done when: `uv run pytest tests/prices -q` passes, including a new test for the retry.
Do not change the public signature or touch other modules.
```

- One contained task per job, with a check that proves it is done.
- Create the worktree first: `git -C /abs/repo worktree add /abs/worktree -b codex/retry`.
- After `done`: read the diff, run the check yourself, then present it. The worktree is
  yours to keep or delete (`git worktree remove`).

## Follow-ups (`resume`)

Send only the new part. Codex keeps the earlier turn, rules and format included.

```markdown
Finding 2 (timeout during refresh): show the exact sequence of calls that leaves the
session without a token. I could not reproduce it with tests/auth/test_refresh.py.
```

## Things that make results worse

- Telling Codex the answer you expect: it tends to agree.
- "Review everything": no questions means a generic list.
- Huge pasted content: give paths; Codex reads them itself.
- Asking for a fix in review mode: it cannot write there. Use a task job.
