---
description: Apply the open inline comments captured by Koment
allowed-tools: mcp__koment__list_comments, mcp__koment__get_comment, mcp__koment__resolve_comment, mcp__koment__mark_drifted, mcp__koment__list_projects, Task, Read, Edit, Write, Grep, Glob
argument-hint: "[here | all | <comment id>… | <path fragment>]"
---

Each comment is a note a human attached to a range of lines. `$ARGUMENTS` says which ones to
apply.

## Choose the set

| `$ARGUMENTS` | The set | Read it with |
| --- | --- | --- |
| empty, or `here` | the open comments of this repository | `list_comments` with `status: "open"` |
| `all` | the open comments of every project | `list_comments` with `status: "open"` and `project: "all"` |
| one or more ids | those comments, whatever their status | `get_comment` once per id |
| anything else | the open comments of this repository whose `path` contains it | `list_comments`, then filter |

Ids come as words separated by spaces, and this is how the app's play button asks. Use
`get_comment` for them rather than `list_comments`, because a comment the human wants to run
again is already resolved and the open list does not hold it.

If the set is empty, say so and stop.

## Which file a comment points at

`path` is the absolute path of the file and is the one to open. `file` is the same file relative
to `projectRoot` and is there to read, not to resolve — two projects can hold the same relative
path. Use `path`.

## A comment with no file

Some comments come from an app that holds no file — a Slack conversation, a web page, a chat.
Their `path` and `projectRoot` are empty, `anchor.confidence` is `unresolved`, and there is
nothing to re-anchor. A comment whose `method` is `window` was written about the window itself
and never had a selection, so `anchor.selectedText` is empty and `line` is `0`. It carries a
`path` when the window held a file, and the note is then about that whole file. Three fields say where the note came from:

- `windowTitle`, raw and unparsed. For Slack it names the channel or the person, and it carries
  the unread counter of the moment, so read past that.
- `sourceURL`, the address of the window. A browser gives the Notion page or the Jira ticket;
  Slack gives nothing.
- `bundleIdentifier`, the app itself, where its display name is ambiguous.

Work out from the note and that context what the human is asking for, and where it belongs. Ask
when the note does not say enough. Never guess which repository or which file it meant.

Keep these comments yourself, and never send one to a sub-agent: an agent cannot ask you
anything, and these are the comments most likely to need a question.

## One agent per file

Group by `path` the comments that have one. A comment with no `path` stays with you, per the
section above.

- One group: do the work yourself. A single file needs no agent.
- Two or more groups: send one `Task` sub-agent per group, of type `general-purpose`, and start
  them all in one message so they run at once.

Never split one file over two agents, and never give one agent two files. Two agents editing one
file at the same time is the failure this grouping exists to stop. `all` needs nothing further:
groups from different repositories are independent already.

## What to tell each agent

Put in the prompt everything the agent cannot ask for:

- the absolute `path`, and that it must change no other file;
- for every comment in the group, its `id`, `note`, `line`, `endLine`, `anchor.selectedText`,
  `anchor.before`, `anchor.after` and `anchor.confidence`;
- the two sections below, **Locate each comment** and **Apply**, in full;
- that it calls `resolve_comment` itself, per comment, as it finishes that comment;
- that it answers with one line per comment.

An agent cannot reach the human. Where **Apply** says to ask, an agent instead leaves the file
alone, leaves the comment open, and returns the question. Collect those questions and put them
to the human yourself at the end.

## Locate each comment before you change anything

The stored `line` is where the code was at capture time and may have moved. When
`anchor.confidence` is `document-only` the line was never known — the file is right and the line
is a placeholder, so go straight to step 3. When `anchor.selectedText` is empty there is nothing
to locate: read the whole file and apply the note to it, and ask when the note does not say where
it belongs.

1. Read the file at `path`.
2. If the lines at `line`–`endLine` still match `anchor.selectedText`, use them.
3. Otherwise search the file for `anchor.selectedText`. One match means you found it.
4. Otherwise search for the `anchor.before` and `anchor.after` context lines and take the range
   between them.
5. If none of that resolves, do not guess. Call `mark_drifted` with what you looked for and did
   not find, and leave the file alone.

## Apply

Make the change the note asks for. Follow the conventions of the file and of the project's
CLAUDE.md. Ask before you change anything the note does not cover.

## Close the loop

Call `resolve_comment` with the id and one line saying what you changed, as soon as that comment
is applied — not in a batch at the end. A resolved comment leaves the open list at once, so the
next `list_comments` holds the work that is left and nothing else. The app updates its history
window the moment you do this, whether or not it was running when you started.

Never edit the comment store yourself. The tools are the only way in.

Finish with one line per comment: the file and line, what you changed, or why you marked it
drifted or skipped it. Then ask about anything an agent sent back unapplied.
