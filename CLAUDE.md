# CLAUDE.md

This project mimics the Reminders app from macOS. I want to have an open source,
tidy, simple to-do app that can handle the tasks from the
[Tasks.org](https://tasks.org) android application, with all subtasks,
reccurrance and other features.

Some of the main features of the application is aimed to be:

- Synchronise tasks with CalDAV server (Nextcloud in particular).
- Match the settings of a tasks with the Tasks.org application.
- The User Interface is aimed to match the macOS Reminder app.
- It must be always possible the to see the synchronisation status.
- Explicit synchronisation is possible next to scheduled and push.
- Allow for conflict resolution if there is any conflict.

## Development commands

- `make test` – Builds and runs the e2e tests of the project
- `make lint` – Static analysis of the project.
- `make` – Builds the main application

## Important Rules and Constraints

- I'm using the TDD practiced described in the [Growing Object-Oriented Software
  Guided by Tests](https://github.com/MnkGitBox/Programming-Books/blob/master/Growing%20Object%20Oriented%20Software%20Guided%20by%20Tests.pdf)
  book.
- Any new behaviour must be tested.
- The application is using SwiftUI.
- A mock CalDAV service must be used to test the synchronisation features.

## Commit messages

The development cycle must produce commit messages.

- Commit messages must conform to [conventional commits](https://www.conventionalcommits.org)
- The body of the commit message must contain non-trivial details.
- The message must not be a english translation of the commit message: it must
  give a context why the change was made.

## Development cycle

I'm practicing test-driven development. The cycle goes like this:

1. Write a test for the desired behaviour. Build enough scaffolding for the test
   to fail in such a way to reveal the lack of the desired behaviour.
2. Demonstrate the failure through running the test.
3. Offer a commit message and prompt for review the changes and let the
   developer make the commit.
4. Read back any changes the developer might have made to the message or to the
   code.
5. Build the implementation.
6. Demonstrate of passing the test.
7. Review the test and implementation, offer possible steps for refactoring.

Along the development, always make sure that the code passes the build, the
tests, and static analysis.
