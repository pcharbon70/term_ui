Create a recoverable checkpoint commit.

Follow these steps:

- Make sure any code quality tools are passing, eg clippy and tests for rust,
  credo and exunit for elixir.
  - also fix minor issues
- Analyse uncommitted changes in the local working tree.
- Update the current plan/project file with the current progress status.
- Remove any temporary working files that are not meant to be part of the
  ongoing project.
- Create logical commits using the conventional commit syntax to make sure our
  changes aren't lost. NO CLAUDE ATTRIBUTIONS!
- Ask Barnabas if he wants to continue on to the next item in the plan
