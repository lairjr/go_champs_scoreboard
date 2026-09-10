defmodule Mix.Tasks.Rabbitmq.Declare do
  @shortdoc "Declares the RabbitMQ topology from priv/rabbitmq/definitions.json"

  @moduledoc """
  Declares every exchange, queue and binding described by
  `priv/rabbitmq/definitions.json` over AMQP.

  ## Usage

      mix rabbitmq.declare

  This is the deploy path. It runs in the Heroku release phase (see `Procfile`),
  against the broker named by the `RABBIT_MQ_*` config vars, so no environment
  needs a manual step and no application needs management credentials.

  Declares are idempotent: running it against a broker that already matches the
  file changes nothing, which is why all three services can run it on every
  deploy. When the broker disagrees with the file — an argument that differs, a
  `durable` flag that was flipped by hand — the broker answers
  `PRECONDITION_FAILED`, this task fails, and the deploy stops with the
  offending object named.

  The task deliberately does **not** start the application. The application
  verifies the topology at boot and refuses to start when it is missing, so
  starting it here would deadlock the very run that is supposed to create it.
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
          declare(conn)
        after
          AMQP.Connection.close(conn)
        end

      {:error, reason} ->
        Mix.raise("""
        Could not connect to RabbitMQ: #{inspect(reason)}

        The connection comes from RABBIT_MQ_HOST, RABBIT_MQ_PORT, RABBIT_MQ_USERNAME,
        RABBIT_MQ_PASSWORD and RABBIT_MQ_VHOST.
        """)
    end
  end

  defp declare(conn) do
    {:ok, chan} = AMQP.Channel.open(conn)

    case Topology.declare_all(chan) do
      :ok ->
        Mix.shell().info("RabbitMQ topology declared from #{Topology.path()}")

      {:error, {object, reason}} ->
        Mix.raise("""
        The broker rejected #{object}.

        #{inspect(reason)}

        The broker holds a version of this object that disagrees with
        #{Topology.path()}. Either the file is wrong for this environment, or the
        object was changed by hand.

        The run stops here, so every object listed before this one in the file is
        already declared. That is safe to re-run once the disagreement is settled:
        declares are idempotent.
        """)
    end
  end
end
