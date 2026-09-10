defmodule GoChampsScoreboard.Infrastructure.RabbitMQ.TopologyTest do
  use ExUnit.Case, async: true

  alias GoChampsScoreboard.Infrastructure.RabbitMQ.Topology

  # These guard the vendored copy of definitions.json, which CI also compares
  # against go-champs-local-infra. A re-vendor that drops an object, or renames
  # one on only one side of a binding, is a broker the application can reach but
  # cannot publish through — and nothing else in the suite would notice.
  describe "load!/0" do
    setup do
      %{definitions: Topology.load!()}
    end

    test "reads the vendored definitions file", %{definitions: definitions} do
      assert File.exists?(Topology.path())
      assert %{"exchanges" => _, "queues" => _, "bindings" => _} = definitions
    end

    test "declares the exchange this application publishes to", %{definitions: definitions} do
      assert Enum.any?(definitions["exchanges"], &(&1["name"] == "game-events"))
    end

    test "every binding points at objects the same file declares", %{definitions: definitions} do
      exchanges = MapSet.new(definitions["exchanges"], & &1["name"])
      queues = MapSet.new(definitions["queues"], & &1["name"])

      for binding <- definitions["bindings"] do
        assert MapSet.member?(exchanges, binding["source"]),
               "binding source #{binding["source"]} is not a declared exchange"

        destinations =
          case binding["destination_type"] do
            "queue" -> queues
            "exchange" -> exchanges
          end

        assert MapSet.member?(destinations, binding["destination"]),
               "binding destination #{binding["destination"]} is not a declared " <>
                 "#{binding["destination_type"]}"
      end
    end

    test "no object carries a vhost, which comes from the connection", %{definitions: definitions} do
      objects = definitions["exchanges"] ++ definitions["queues"] ++ definitions["bindings"]

      for object <- objects do
        refute Map.has_key?(object, "vhost"),
               "#{inspect(object["name"] || object["destination"])} pins a vhost; on CloudAMQP it is not `/`"
      end
    end

    test "every exchange is durable", %{definitions: definitions} do
      # game-events and dead-letter-exchange were transient for years, so a
      # broker restart dropped them and every binding on them. Going back is a
      # delete-and-recreate migration, not an edit — see
      # `Mix.Tasks.Rabbitmq.Migrate.ExchangeDurability`.
      for exchange <- definitions["exchanges"] do
        assert exchange["durable"], "exchange #{exchange["name"]} is not durable"
      end
    end

    test "the live-mode queue still dead-letters", %{definitions: definitions} do
      live_mode = Enum.find(definitions["queues"], &(&1["name"] == "game-events-live-mode"))

      assert live_mode["arguments"]["x-dead-letter-exchange"] == "dead-letter-exchange"
    end
  end
end
