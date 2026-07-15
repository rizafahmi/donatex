# AGENTS.md

## Project Overview

Single-user livestream donation system.
Elixir 1.18, Phoenix 1.8, SQLite 3, Tailwind 4

## Quick Start

- Install: `mix setup`
- Start:  `mix phx.server` or inside IEx REPL with `iex -S mix phx.server`
- Test: `mix test`
- Full verification: `mix precommit`

## At session start (clock in)
1. Read [PROGRESS.md](docs/PROGRESS.md) for current state
2. Read [DECISIONS.md](docs/DECISIONS.md) for important decisions
3. Run `mix test` to confirm the repo is in a consistent state
4. Continue from PROGRESS.md “Next Steps”

## Before session end (clock out)
1. Update [PROGRESS.md](docs/PROGRESS.md)
2. Run `mix test` (or `mix precommit` for full verification)
3. Commit all completed work

## Constraints
- The app is a single-user, single-streamer system, not multi-tenant.
- It must have exactly two primary public surfaces: donor page and OBS overlay, plus a simple admin page.
- Donations must be persisted to SQLite.
- The donor flow must use Mayar-generated dynamic QRIS, one per transaction.
- The overlay must show alerts only after payment confirmation.
- Alerts must be queued sequentially, never overlap, and auto-dismiss after 5 seconds.
- The overlay must recover missed alerts by loading paid AND alerted = false donations from storage after restart.
- Webhook handling must write to DB before broadcast.
- Duplicate webhook deliveries must be deduplicated by mayar_transaction_id.
- The admin page must allow manual replay of missed alerts.
- The donor flow must work on mobile.
- The admin auth should stay simple for MVP: basic auth, not a full auth system.
- The overlay route is `/overlay` and intentionally unauthenticated for the single-user MVP.
- Out-of-scope items are hard “not now” constraints for MVP: no viewer accounts, no multi-streamer support, no analytics dashboard, no custom alert themes, no sound effects, no YouTube API integration, no tipping goals, no mobile app.
- HTTP integration should use `Req`, not `HTTPoison`, `Tesla`, or `:httpc`.
- Forms in LiveView must use `to_form/2` and the shared `<.input>` component.
LiveView pages should follow Phoenix 1.8 layout conventions, including wrapping content in `<Layouts.app ...>`.
- For collections in LiveView, the project guidance prefers streams where appropriate.
- Do not design for multiple streamers or per-stream sessions.
- Do not add richer admin/reporting features beyond donation list + replay.
- Do not add extra payment methods beyond QRIS.
- Do not introduce a separate queue service or external broker unless the simple single-node LiveView + PubSub approach proves insufficient.

## Guidelines
- Use ExAST when code structure matters; prefer it over regex for Elixir code transformations. Example:

```shell
mix ex_ast.search  'IO.inspect(_)'
mix ex_ast.replace 'IO.inspect(expr, _)' 'Logger.debug(inspect(expr))' lib/
mix ex_ast.diff lib/old.ex lib/new.ex
```

## Topic Docs

- [Elixir Guideline](docs/elixir-guide.md)
- [Mix Guideline](docs/mix-guide.md)
- [Phoenix v1.8 Guidelines](docs/phoenix-guide.md)
- [Ecto Guideline](docs/ecto-guide.md)
- [Frontend Guideline](docs/FRONTEND.md)
- [Design Guideline](docs/DESIGN.md)
- [Testing Guideline](docs/test-guide.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Plan Index](docs/PLAN.md)
- [Progress](docs/PROGRESS.md)
- [Decision Log](docs/DECISIONS.md)
- [Architecture Decisions (ADRs)](docs/decisions)

<!-- usage-rules-start -->
<!-- igniter-start -->
## igniter usage
_A code generation and project patching framework_

# Rules for working with Igniter

## Understanding Igniter

Igniter is a code generation and project patching framework that enables semantic manipulation of Elixir codebases. It provides tools for creating intelligent generators that can both create new files and modify existing ones safely. Igniter works with AST (Abstract Syntax Trees) through Sourceror.Zipper to make precise, context-aware changes to your code.

## Available Modules

### Project-Level Modules (`Igniter.Project.*`)

- **`Igniter.Project.Application`** - Working with Application modules and application configuration
- **`Igniter.Project.Config`** - Modifying Elixir config files (config.exs, runtime.exs, etc.)
- **`Igniter.Project.Deps`** - Managing dependencies declared in mix.exs
- **`Igniter.Project.Formatter`** - Interacting with .formatter.exs files
- **`Igniter.Project.IgniterConfig`** - Managing .igniter.exs configuration files
- **`Igniter.Project.MixProject`** - Updating project configuration in mix.exs
- **`Igniter.Project.Module`** - Creating and managing modules with proper file placement
- **`Igniter.Project.TaskAliases`** - Managing task aliases in mix.exs
- **`Igniter.Project.Test`** - Working with test and test support files

### Code-Level Modules (`Igniter.Code.*`)

- **`Igniter.Code.Common`** - General purpose utilities for working with Sourceror.Zipper
- **`Igniter.Code.Function`** - Working with function definitions and calls
- **`Igniter.Code.Keyword`** - Manipulating keyword lists
- **`Igniter.Code.List`** - Working with lists in AST
- **`Igniter.Code.Map`** - Manipulating maps
- **`Igniter.Code.Module`** - Working with module definitions and usage
- **`Igniter.Code.String`** - Utilities for string literals
- **`Igniter.Code.Tuple`** - Working with tuples

<!-- igniter-end -->
<!-- usage_rules-start -->
## usage_rules usage
_A config-driven dev tool for Elixir projects to manage AGENTS.md files and agent skills from dependencies_

## Using Usage Rules

Many packages have usage rules, which you should *thoroughly* consult before taking any
action. These usage rules contain guidelines and rules *directly from the package authors*.
They are your best source of knowledge for making decisions.

## Modules & functions in the current app and dependencies

When looking for docs for modules & functions that are dependencies of the current project,
or for Elixir itself, use `mix usage_rules.docs`

```
# Search a whole module
mix usage_rules.docs Enum

# Search a specific function
mix usage_rules.docs Enum.zip

# Search a specific function & arity
mix usage_rules.docs Enum.zip/1
```


## Searching Documentation

You should also consult the documentation of any tools you are using, early and often. The best 
way to accomplish this is to use the `usage_rules.search_docs` mix task. Once you have
found what you are looking for, use the links in the search results to get more detail. For example:

```
# Search docs for all packages in the current application, including Elixir
mix usage_rules.search_docs Enum.zip

# Search docs for specific packages
mix usage_rules.search_docs Req.get -p req

# Search docs for multi-word queries
mix usage_rules.search_docs "making requests" -p req

# Search only in titles (useful for finding specific functions/modules)
mix usage_rules.search_docs "Enum.zip" --query-by title
```


<!-- usage_rules-end -->
<!-- usage_rules:elixir-start -->
## usage_rules:elixir usage
# Elixir Core Usage Rules

## Pattern Matching
- Use pattern matching over conditional logic when possible
- Prefer to match on function heads instead of using `if`/`else` or `case` in function bodies
- `%{}` matches ANY map, not just empty maps. Use `map_size(map) == 0` guard to check for truly empty maps

## Error Handling
- Use `{:ok, result}` and `{:error, reason}` tuples for operations that can fail
- Avoid raising exceptions for control flow
- Use `with` for chaining operations that return `{:ok, _}` or `{:error, _}`

## Common Mistakes to Avoid
- Elixir has no `return` statement, nor early returns. The last expression in a block is always returned.
- Don't use `Enum` functions on large collections when `Stream` is more appropriate
- Avoid nested `case` statements - refactor to a single `case`, `with` or separate functions
- Don't use `String.to_atom/1` on user input (memory leak risk)
- Lists and enumerables cannot be indexed with brackets. Use pattern matching or `Enum` functions
- Prefer `Enum` functions like `Enum.reduce` over recursion
- When recursion is necessary, prefer to use pattern matching in function heads for base case detection
- Using the process dictionary is typically a sign of unidiomatic code
- Only use macros if explicitly requested
- There are many useful standard library functions, prefer to use them where possible

## Function Design
- Use guard clauses: `when is_binary(name) and byte_size(name) > 0`
- Prefer multiple function clauses over complex conditional logic
- Name functions descriptively: `calculate_total_price/2` not `calc/2`
- Predicate function names should not start with `is` and should end in a question mark.
- Names like `is_thing` should be reserved for guards

## Data Structures
- Use structs over maps when the shape is known: `defstruct [:name, :age]`
- Prefer keyword lists for options: `[timeout: 5000, retries: 3]`
- Use maps for dynamic key-value data
- Prefer to prepend to lists `[new | list]` not `list ++ [new]`

## Mix Tasks

- Use `mix help` to list available mix tasks
- Use `mix help task_name` to get docs for an individual task
- Read the docs and options fully before using tasks

## Testing
- Run tests in a specific file with `mix test test/my_test.exs` and a specific test with the line number `mix test path/to/test.exs:123`
- Limit the number of failed tests with `mix test --max-failures n`
- Use `@tag` to tag specific tests, and `mix test --only tag` to run only those tests
- Use `assert_raise` for testing expected exceptions: `assert_raise ArgumentError, fn -> invalid_function() end`
- Use `mix help test` to for full documentation on running tests

## Debugging

- Use `dbg/1` to print values while debugging. This will display the formatted value and other relevant information in the console.

<!-- usage_rules:elixir-end -->
<!-- usage_rules:otp-start -->
## usage_rules:otp usage
# OTP Usage Rules

## GenServer Best Practices
- Keep state simple and serializable
- Handle all expected messages explicitly
- Use `handle_continue/2` for post-init work
- Implement proper cleanup in `terminate/2` when necessary

## Process Communication
- Use `GenServer.call/3` for synchronous requests expecting replies
- Use `GenServer.cast/2` for fire-and-forget messages.
- When in doubt, use `call` over `cast`, to ensure back-pressure
- Set appropriate timeouts for `call/3` operations

## Fault Tolerance
- Set up processes such that they can handle crashing and being restarted by supervisors
- Use `:max_restarts` and `:max_seconds` to prevent restart loops

## Task and Async
- Use `Task.Supervisor` for better fault tolerance
- Handle task failures with `Task.yield/2` or `Task.shutdown/2`
- Set appropriate task timeouts
- Use `Task.async_stream/3` for concurrent enumeration with back-pressure

<!-- usage_rules:otp-end -->
<!-- usage-rules-end -->

## `docs/`

The `docs/` folder contains the initial PRD and per-milestone prompts used to scaffold this codebase during its initial build-out phase. These files are **temporary** — they exist for documentation and guidance only. They are **not** functional: no code, configuration, or runtime logic in this codebase should import, reference, or depend on anything inside `docs/`.

Do not treat `docs/` as long-living documentation for the codebase. The codebase will evolve past the assumptions and decisions captured here. Once the initial milestones are complete, this folder is expected to be deleted.
