defmodule GoChampsScoreboard.Infrastructure.RabbitMQ.Topology do
  @moduledoc """
  The platform's RabbitMQ topology, read from `priv/rabbitmq/definitions.json`.

  That file is a verbatim copy of `rabbitmq/definitions.json` in
  [go-champs-local-infra](https://github.com/go-champs-org/go-champs-local-infra),
  which is the single source of truth for every environment. CI fails when the
  copy diverges, so it is re-vendored, never edited here.

  Two entry points, deliberately different:

    * `declare_all/1` is the deploy path. The release phase declares the whole
      topology over AMQP (see `Mix.Tasks.Rabbitmq.Declare`). A declare is
      idempotent while the broker already matches the file, and answers
      `PRECONDITION_FAILED` when it doesn't — which is what turns drift into a
      failed deploy instead of a message that silently goes nowhere weeks later.

    * `verify/2` is the boot path. Passive declares assert that an object
      exists without creating it, so the app refuses to run against a broker
      that is missing what it publishes to.

  The management API is not used for either. Importing definitions requires the
  `administrator` tag, which the CloudAMQP user does not have, and an import
  whose arguments disagree with the broker returns `204 success` while leaving
  the broker untouched.
  """

  require Logger

  alias AMQP.{Channel, Connection, Exchange, Queue}

  @definitions_path ["priv", "rabbitmq", "definitions.json"]

  @exchange_types %{
    "direct" => :direct,
    "topic" => :topic,
    "fanout" => :fanout,
    "headers" => :headers
  }

  @type object :: {:exchange, String.t()} | {:queue, String.t()}
  @type failure :: {:error, {String.t(), term()}}

  @doc "Absolute path of the vendored definitions file."
  @spec path() :: String.t()
  def path do
    Application.app_dir(:go_champs_scoreboard, @definitions_path)
  end

  @doc "Parses the vendored definitions file."
  @spec load!() :: map()
  def load! do
    path() |> File.read!() |> Jason.decode!()
  end

  @doc """
  Declares every exchange, queue and binding in the file, in that order.

  Fails fast: the first object the broker disagrees with stops the run and is
  named in the error, because a `PRECONDITION_FAILED` closes the channel and
  every declare after it would fail for the wrong reason.
  """
  @spec declare_all(Channel.t()) :: :ok | failure()
  def declare_all(%Channel{} = chan) do
    definitions = load!()

    with :ok <- each(definitions["exchanges"], &declare_exchange(chan, &1)),
         :ok <- each(definitions["queues"], &declare_queue(chan, &1)) do
      each(definitions["bindings"], &declare_binding(chan, &1))
    end
  end

  @doc """
  Passively asserts that each object already exists, creating nothing.

  A missing object closes the channel, so the caller gets one failure and the
  channel it passed in is no longer usable.
  """
  @spec verify(Channel.t(), [object()]) :: :ok | failure()
  def verify(%Channel{} = chan, objects) do
    each(objects, &verify_one(chan, &1))
  end

  @doc """
  Deletes every exchange the broker still holds as non-durable that the file
  marks durable, so that a following `declare_all/1` recreates it durable and
  restores its bindings.

  This exists because `game-events` and `dead-letter-exchange` were declared
  without `durable: true` for years. An exchange's durability cannot be changed
  in place — the only way across is to delete and recreate — and that drops
  every binding on it, which is why the declare has to run right after.

  It is narrow on purpose. An exchange is deleted only after a probe confirms
  the broker holds a **non-durable** one of that name: an object the broker
  itself would have discarded at its next restart. Anything else — already
  durable, missing, or disagreeing in some other way — is left alone for
  `declare_all/1` to create or to fail on.

  Takes a connection rather than a channel because each probe may be refused,
  and a refused declare closes the channel it ran on.
  """
  @spec recreate_non_durable_exchanges(Connection.t()) :: {:ok, [String.t()]} | failure()
  def recreate_non_durable_exchanges(%Connection{} = conn) do
    load!()["exchanges"]
    |> Enum.filter(&Map.get(&1, "durable", false))
    |> Enum.reduce_while({:ok, []}, fn exchange, {:ok, recreated} ->
      case recreate_if_non_durable(conn, exchange) do
        {:ok, nil} -> {:cont, {:ok, recreated}}
        {:ok, name} -> {:cont, {:ok, [name | recreated]}}
        failure -> {:halt, failure}
      end
    end)
    |> case do
      {:ok, recreated} -> {:ok, Enum.reverse(recreated)}
      failure -> failure
    end
  end

  defp recreate_if_non_durable(conn, %{"name" => name} = exchange) do
    with :ok <- probe(conn, &Exchange.declare(&1, name, :direct, passive: true)),
         :ok <- probe(conn, &declare_exchange_as(&1, exchange, false)) do
      case run("exchange #{name}", fn ->
             {:ok, chan} = Channel.open(conn)

             try do
               Exchange.delete(chan, name)
             after
               close(chan)
             end
           end) do
        :ok -> {:ok, name}
        failure -> failure
      end
    else
      # Missing, already durable, or disagreeing in some other way. Either way
      # this is not a durability migration, so `declare_all/1` owns it.
      :refused -> {:ok, nil}
    end
  end

  defp declare_exchange_as(chan, exchange, durable) do
    Exchange.declare(chan, exchange["name"], exchange_type(exchange["name"], exchange["type"]),
      durable: durable,
      auto_delete: Map.get(exchange, "auto_delete", false),
      internal: Map.get(exchange, "internal", false),
      arguments: arguments(exchange["name"], exchange["arguments"])
    )
  end

  # Runs one declare on a channel of its own and reports only whether the broker
  # accepted it. Unlike `run/2` a refusal is an expected answer here, not a
  # failure — it is how the broker is asked what it already holds.
  defp probe(conn, fun) do
    {:ok, chan} = Channel.open(conn)

    try do
      case fun.(chan) do
        :ok -> :ok
        {:ok, _} -> :ok
        {:error, _} -> :refused
      end
    catch
      :exit, _ -> :refused
    after
      close(chan)
    end
  end

  defp close(chan) do
    if Process.alive?(chan.pid), do: Channel.close(chan)
    :ok
  catch
    :exit, _ -> :ok
  end

  defp verify_one(chan, {:exchange, name}) do
    # A passive declare ignores every field but the name, so the type passed
    # here never reaches the broker's comparison — it only has to be valid.
    run("exchange #{name}", fn -> Exchange.declare(chan, name, :direct, passive: true) end)
  end

  defp verify_one(chan, {:queue, name}) do
    run("queue #{name}", fn -> Queue.declare(chan, name, passive: true) end)
  end

  defp declare_exchange(chan, %{"name" => name} = exchange) do
    run("exchange #{name}", fn ->
      Exchange.declare(chan, name, exchange_type(name, exchange["type"]),
        durable: Map.get(exchange, "durable", false),
        auto_delete: Map.get(exchange, "auto_delete", false),
        internal: Map.get(exchange, "internal", false),
        arguments: arguments(name, exchange["arguments"])
      )
    end)
  end

  defp declare_queue(chan, %{"name" => name} = queue) do
    run("queue #{name}", fn ->
      Queue.declare(chan, name,
        durable: Map.get(queue, "durable", false),
        auto_delete: Map.get(queue, "auto_delete", false),
        arguments: arguments(name, queue["arguments"])
      )
    end)
  end

  defp declare_binding(chan, %{"destination_type" => "queue"} = binding) do
    run(binding_label(binding), fn ->
      Queue.bind(chan, binding["destination"], binding["source"],
        routing_key: binding["routing_key"],
        arguments: arguments(binding_label(binding), binding["arguments"])
      )
    end)
  end

  defp declare_binding(chan, %{"destination_type" => "exchange"} = binding) do
    run(binding_label(binding), fn ->
      Exchange.bind(chan, binding["destination"], binding["source"],
        routing_key: binding["routing_key"],
        arguments: arguments(binding_label(binding), binding["arguments"])
      )
    end)
  end

  defp binding_label(binding) do
    "binding #{binding["source"]} -> #{binding["destination_type"]} " <>
      "#{binding["destination"]} (#{binding["routing_key"]})"
  end

  defp each(objects, fun) do
    Enum.reduce_while(objects, :ok, fn object, :ok ->
      case fun.(object) do
        :ok -> {:cont, :ok}
        failure -> {:halt, failure}
      end
    end)
  end

  # A declare the broker rejects closes the channel, and `:amqp_channel.call/2`
  # surfaces that as an exit rather than an error tuple, so both shapes have to
  # be caught to name the offending object.
  defp run(label, fun) do
    case fun.() do
      :ok -> :ok
      {:ok, _} -> :ok
      {:error, reason} -> {:error, {label, reason}}
    end
  catch
    :exit, reason -> {:error, {label, reason}}
  end

  defp exchange_type(name, type) do
    case Map.fetch(@exchange_types, type) do
      {:ok, exchange_type} ->
        exchange_type

      :error ->
        raise ArgumentError,
              "exchange #{name} has unknown type #{inspect(type)} in #{path()}"
    end
  end

  defp arguments(_label, nil), do: []

  defp arguments(label, arguments) when is_map(arguments) do
    Enum.map(arguments, fn {name, value} -> {name, amqp_type(label, name, value), value} end)
  end

  defp amqp_type(_label, _name, value) when is_boolean(value), do: :bool
  defp amqp_type(_label, _name, value) when is_binary(value), do: :longstr
  defp amqp_type(_label, _name, value) when is_integer(value), do: :long
  defp amqp_type(_label, _name, value) when is_float(value), do: :float

  defp amqp_type(label, name, value) do
    raise ArgumentError,
          "#{label} has argument #{name} with unsupported value #{inspect(value)} in #{path()}"
  end
end
