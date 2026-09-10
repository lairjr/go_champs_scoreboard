defmodule Mix.Tasks.Rabbitmq.Migrate.ExchangeDurability do
  @shortdoc "Recreates exchanges the broker still holds as non-durable"

  @moduledoc """
  Deletes every exchange the broker still holds as non-durable that
  `priv/rabbitmq/definitions.json` marks durable, so the `mix rabbitmq.declare`
  that follows recreates it durable and restores its bindings.

  ## Usage

      mix rabbitmq.migrate.exchange_durability

  It runs immediately before `mix rabbitmq.declare` in the release phase (see
  `Procfile`), and the two belong together: deleting an exchange drops every
  binding on it, and the declare is what puts them back.

  ## Why this exists

  `game-events` and `dead-letter-exchange` were declared without `durable: true`
  for years, so every broker restart dropped both and every binding on them. The
  application quietly recreated them on its next boot, which is what kept
  production working — and that silent repair went away when the application
  started asserting the topology instead of declaring it. An exchange's
  durability cannot be changed in place; delete and recreate is the only way
  across.

  ## Why it is safe to leave in the release phase

  An exchange is deleted only after a probe confirms the broker holds a
  **non-durable** one of that name — an object the broker itself would discard at
  its next restart, along with the same bindings this run drops. Anything else is
  left alone: an exchange that is already durable, one that does not exist, and
  one that disagrees with the file in some other way all fall through to
  `mix rabbitmq.declare`, which creates it or fails loudly.

  So the first deploy after this lands migrates, and every deploy after it prints
  that there was nothing to do.

  ## What it does not do

  Durable exchanges and durable queues do not make a *message* survive a broker
  restart. That needs `persistent: true` on publish, which is tracked separately.
  """

  use Mix.Task

  alias GoChampsScoreboard.Infrastructure.RabbitMQ.Topology

  @requirements ["app.config"]

  @impl Mix.Task
  def run(_argv) do
    {:ok, _apps} = Application.ensure_all_started(:amqp)

    config =
      Application.get_env(:go_champs_scoreboard, GoChampsScoreboard.Infrastructure.RabbitMQ)

    case AMQP.Connection.open(config) do
      {:ok, conn} ->
        try do
          migrate(conn)
        after
          AMQP.Connection.close(conn)
        end

      {:error, reason} ->
        Mix.raise("Could not connect to RabbitMQ: #{inspect(reason)}")
    end
  end

  defp migrate(conn) do
    case Topology.recreate_non_durable_exchanges(conn) do
      {:ok, []} ->
        Mix.shell().info("No non-durable exchanges to migrate.")

      {:ok, deleted} ->
        Mix.shell().info(
          "Deleted #{Enum.join(deleted, ", ")} — non-durable. " <>
            "`mix rabbitmq.declare` recreates them durable, with their bindings."
        )

      {:error, {object, reason}} ->
        Mix.raise("""
        Could not delete #{object}.

        #{inspect(reason)}
        """)
    end
  end
end
