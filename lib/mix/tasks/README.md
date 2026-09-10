# Mix Tasks

This directory contains custom Mix tasks for the Go Champs Scoreboard application. These tasks provide command-line utilities for various administrative, data-export, and maintenance operations.

It lives under `lib/mix/tasks/` (not a top-level `mix/tasks/`) because Mix only compiles code under `lib/` (see `elixirc_paths/1` in `mix.exs`) — a task placed outside `lib/` won't be picked up as a `mix <name>` command.

## Available Tasks

### 1. FIBA Scoresheet Game Export (`mix fiba_scoresheet.export_game`)

Exports a game's full event log sequence into an anonymized JSON fixture that can be replayed offline to reproduce and regression-test its FIBA scoresheet contract (see `test/go_champs_scoreboard/sports/basketball/reports/fiba_scoresheet_regression_test.exs` and `GoChampsScoreboard.FibaScoresheetScenarios.replay_real_game_fixture!/1`).

**Usage:**
```bash
mix fiba_scoresheet.export_game <game_id> <output_name>
```

**Arguments:**
- `game_id` - The ID of the game to export (required)
- `output_name` - File name to write, without extension (required). Output goes to `test/fixtures/fiba_scoresheet/real_games/<output_name>.json`.

**What it does:**
- Read-only — it only calls `EventLogs.get_all_by_game_id/2` and never writes to the database.
- Anonymizes every real player/coach/official name, license number, signature, and tournament/organization/sponsor detail it finds, deterministically (the same person always maps to the same placeholder across the whole fixture).
- Leaves every score/stat/clock-timing value untouched, since those are what make the fixture useful for regression testing.
- Writes the fixture to `test/fixtures/fiba_scoresheet/real_games/<output_name>.json` **and** prints the same JSON to stdout, so it can be captured directly without a separate `cat` step.

**Running against production (via Heroku):**

This app runs on Heroku, so the simplest way to export a real game is `heroku run`, redirecting stdout straight to a local file (the on-disk copy on the dyno itself is discarded when the one-off dyno exits, which is fine — stdout is what you actually want):

```bash
heroku run "mix fiba_scoresheet.export_game <game_id> <output_name>" -a go-champs-scoreboard-prod > <output_name>.json
```

Example:

```bash
heroku run "mix fiba_scoresheet.export_game bc29d5da-ea48-40ae-91d1-4126267cc351 final-cbi-05-10-2026" -a go-champs-scoreboard-prod > final-cbi-05-10-2026.json
```

Sanity-check the result is valid JSON before trusting it (e.g. `jq . final-cbi-05-10-2026.json`) — any stray output from the dyno mixed into the stream would break parsing and need to be stripped from the top of the file.

**Running against production (direct database connection):**

If you're not going through Heroku (e.g. running from your own machine against a read replica), you can instead run the task directly with production credentials:

```bash
MIX_ENV=prod \
SECRET_KEY_BASE=$(mix phx.gen.secret) \
DATABASE_URL="ecto://USER:PASSWORD@HOST/DATABASE_NAME" \
mix fiba_scoresheet.export_game <game_id> <output_name>
```
- `DATABASE_URL` should point at production. Read-only credentials or a replica are strongly preferred — the task itself only reads, but the app boots with whatever permissions the connection grants.
- `SECRET_KEY_BASE` isn't used by the task, but Phoenix requires it to boot under `MIX_ENV=prod`; any value works, `mix phx.gen.secret` generates one.
- Leave `PHX_SERVER` unset so the web server doesn't try to bind a port.
- You'll need network access to the production database from wherever you run this (VPN, bastion host, SSH tunnel, etc.).

The exported file is already anonymized and safe to share — a quick manual look before sharing is still good practice to confirm nothing unexpected slipped through.

### 2. RabbitMQ Topology Declare (`mix rabbitmq.declare`)

Declares every exchange, queue and binding described by `priv/rabbitmq/definitions.json` over AMQP.

**Usage:**
```bash
mix rabbitmq.declare
```

**Arguments:** none. The broker comes from `RABBIT_MQ_HOST`, `RABBIT_MQ_PORT`, `RABBIT_MQ_USERNAME`, `RABBIT_MQ_PASSWORD` and `RABBIT_MQ_VHOST`.

**What it does:**
- Applies the shared platform topology (see the [RabbitMQ topology](../../../README.md#rabbitmq-topology) section) from the vendored copy of the file that `go-champs-local-infra` owns.
- Runs in the Heroku **release phase** on every deploy (see `Procfile`), so no environment needs a manual step and no application needs management credentials.
- Is idempotent. Against a broker that already matches the file it changes nothing, which is why all three services can run it on every deploy and the deploy order stops mattering.
- Fails, naming the object, when the broker disagrees with the file — a differing argument or a `durable` flag flipped by hand answers `PRECONDITION_FAILED`, and the deploy stops there. Objects listed before it in the file are already declared; re-running after the disagreement is settled is safe.
- Deliberately does **not** start the application. The app verifies the topology at boot and refuses to start when it is missing, so starting it here would deadlock the run that is supposed to create it.

### 3. RabbitMQ Exchange Durability Migration (`mix rabbitmq.migrate.exchange_durability`)

Deletes every exchange the broker still holds as **non-durable** that `priv/rabbitmq/definitions.json` marks durable, so the `mix rabbitmq.declare` that follows recreates it durable and restores its bindings.

**Usage:**
```bash
mix rabbitmq.migrate.exchange_durability
```

**Arguments:** none. Same connection variables as `mix rabbitmq.declare`.

**What it does:**
- Runs immediately **before** `mix rabbitmq.declare` in the release phase (see `Procfile`). The two belong together: deleting an exchange drops every binding on it, and the declare is what puts them back.
- Exists because `game-events` and `dead-letter-exchange` were declared without `durable: true` for years, so every broker restart dropped both and all their bindings. The application quietly recreated them on its next boot — and that silent repair disappeared when it started asserting the topology instead of declaring it. Durability cannot be changed in place; delete and recreate is the only way across.
- Deletes an exchange only after probing the broker and confirming it holds a **non-durable** one of that name — an object the broker would have discarded at its next restart anyway, dropping the same bindings. Everything else falls through to `mix rabbitmq.declare`: already durable, missing, or disagreeing some other way.
- Is idempotent. The first deploy after this lands migrates; every deploy after it prints `No non-durable exchanges to migrate.`
- Does **not** make messages survive a restart. That needs `persistent: true` on publish, tracked separately.

## Adding a New Task

- Add the task module under `lib/mix/tasks/`, named `Mix.Tasks.<Namespace>.<Action>` (e.g. `Mix.Tasks.FibaScoresheet.ExportGame`), which maps to the CLI invocation `mix <namespace>.<action>`.
- Keep the argument-parsing (`run/1`) thin and delegate to a plain, testable function, so the task's logic can be exercised directly from tests without shelling out to `mix`.
- Add a numbered entry to this README describing usage, arguments, and what the task does.
