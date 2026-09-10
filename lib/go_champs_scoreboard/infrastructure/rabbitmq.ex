defmodule GoChampsScoreboard.Infrastructure.RabbitMQ do
  use GenServer
  require Logger

  alias GoChampsScoreboard.Infrastructure.RabbitMQ.Topology

  @exchange "game-events"

  # The only object this application touches: it publishes here and consumes
  # nothing. The queues bound to this exchange belong to their own consumers, so
  # a missing consumer queue must not keep the scoreboard from booting —
  # `mandatory: true` on publish is what catches a message that would go nowhere.
  @required_objects [exchange: @exchange]

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(_) do
    case AMQP.Connection.open(
           Application.get_env(:go_champs_scoreboard, GoChampsScoreboard.Infrastructure.RabbitMQ)
         ) do
      {:ok, conn} ->
        case AMQP.Channel.open(conn) do
          {:ok, chan} ->
            verify_topology(chan)

          {:error, reason} ->
            Logger.error("Failed to open channel: #{inspect(reason)}")
            {:stop, reason}
        end

      {:error, reason} ->
        Logger.error("Failed to open connection: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  def publish(payload) do
    GenServer.call(__MODULE__, {:publish, payload})
  end

  def handle_call(
        {:publish, %{message: message, routing_key: routing_key}},
        _from,
        %{channel: chan} = state
      ) do
    Logger.info("Publishing message to RabbitMQ",
      message: message,
      exchange: @exchange,
      routing_key: routing_key
    )

    # `mandatory` makes the broker hand back anything it cannot route instead of
    # dropping it, which is the only evidence we get that the bindings the
    # topology declared are the ones this routing key actually needs.
    AMQP.Basic.publish(chan, @exchange, routing_key, message, mandatory: true)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(msg, _from, state) do
    Logger.warning("Unhandled call: #{inspect(msg)}")
    {:reply, :ok, state}
  end

  @impl true
  def handle_info(
        {:basic_return, payload, %{exchange: exchange, routing_key: routing_key}},
        state
      ) do
    Logger.error("RabbitMQ could not route a published message",
      exchange: exchange,
      routing_key: routing_key,
      message: payload
    )

    {:noreply, state}
  end

  def handle_info(msg, state) do
    Logger.warning("Unhandled info: #{inspect(msg)}")
    {:noreply, state}
  end

  # The topology is applied by `mix rabbitmq.declare` in the release phase, from
  # the same file this check reads. Here we only assert, so that an application
  # never runs against a broker that is missing what it publishes to.
  defp verify_topology(chan) do
    case Topology.verify(chan, @required_objects) do
      :ok ->
        Logger.info("Connected to RabbitMQ")
        AMQP.Basic.return(chan, self())
        {:ok, %{channel: chan}}

      {:error, {object, reason}} ->
        Logger.error(
          "RabbitMQ is missing #{object}: #{inspect(reason)}. " <>
            "Apply the topology with `mix rabbitmq.declare`."
        )

        {:stop, {:missing_topology, object}}
    end
  end
end
