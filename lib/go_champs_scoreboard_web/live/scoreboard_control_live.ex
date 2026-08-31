defmodule GoChampsScoreboardWeb.ScoreboardControlLive do
  alias GoChampsScoreboard.Games.EventLogCache
  alias GoChampsScoreboard.Infrastructure.FeatureFlags
  alias GoChampsScoreboard.Events.ValidatorCreator
  alias GoChampsScoreboard.Games.Games
  alias GoChampsScoreboard.Games.EventLogs
  alias GoChampsScoreboard.Games.Messages.PubSub
  alias GoChampsScoreboard.Games.SnapshotStaleTracker
  alias GoChampsScoreboard.ApiClient
  use GoChampsScoreboardWeb, :live_view
  require Logger

  def mount(%{"game_id" => game_id} = params, %{"api_token" => api_token} = _session, socket) do
    if connected?(socket) do
      PubSub.subscribe(game_id)
    end

    {:ok,
     socket
     |> assign(:api_token, api_token)
     |> assign(:view, params["view"] || "default")
     |> assign(:env, %{
       go_champs_api_token: api_token,
       go_champs_api:
         System.get_env("GO_CHAMPS_API_URL") || "https://go-champs-api-staging.herokuapp.com/"
     })
     |> assign(:feature_flags, FeatureFlags.all_flags())
     |> assign(:inactivity_timer_ref, nil)
     |> assign(:inactivity_timer_tag, nil)
     |> assign_async(:game_state, fn ->
       task =
         Task.async(fn ->
           Games.find_or_bootstrap(game_id, api_token)
         end)

       try do
         result = Task.await(task, 25_000)

         case result do
           {:ok, game_state} ->
             {:ok, %{game_state: game_state}}

           {:error, reason} ->
             Logger.error("Failed to load game #{game_id}: #{inspect(reason)}")
             {:error, reason}

           game_state ->
             {:ok, %{game_state: game_state}}
         end
       catch
         :exit, {:timeout, _} ->
           Logger.error("Timeout loading game #{game_id} after 25s")
           {:error, :timeout}
       end
     end)
     |> assign_async(:recent_events, fn ->
       task =
         Task.async(fn ->
           EventLogCache.get(game_id)
         end)

       try do
         case Task.await(task, 5_000) do
           {:ok, recent_events} -> {:ok, %{recent_events: recent_events}}
           _ -> {:ok, %{recent_events: []}}
         end
       catch
         :exit, {:timeout, _} ->
           Logger.warning("Timeout loading recent events for game #{game_id}")
           {:ok, %{recent_events: []}}
       end
     end)}
  end

  def handle_event("update-player-stat", params, socket) do
    game_id = socket.assigns.game_state.result.id
    {:ok, event} = ValidatorCreator.validate_and_create("update-player-stat", game_id, params)

    {:noreply,
     event
     |> react_and_update_game_state(game_id, socket)}
  end

  def handle_event("update-coach-stat", params, socket) do
    game_id = socket.assigns.game_state.result.id
    {:ok, event} = ValidatorCreator.validate_and_create("update-coach-stat", game_id, params)

    {:noreply,
     event
     |> react_and_update_game_state(game_id, socket)}
  end

  def handle_event("update-clock-state-metadata", params, socket) do
    game_id = socket.assigns.game_state.result.id

    {:ok, event} =
      ValidatorCreator.validate_and_create("update-clock-state-metadata", game_id, params)

    {:noreply,
     event
     |> react_and_update_game_state(game_id, socket)}
  end

  def handle_event("update-players-state", unsigned_params, socket) do
    game_id = socket.assigns.game_state.result.id

    {:ok, event} =
      ValidatorCreator.validate_and_create("update-players-state", game_id, unsigned_params)

    {:noreply,
     event
     |> react_and_update_game_state(game_id, socket)}
  end

  def handle_event("update-team-stat", params, socket) do
    game_id = socket.assigns.game_state.result.id
    {:ok, event} = ValidatorCreator.validate_and_create("update-team-stat", game_id, params)

    {:noreply,
     event
     |> react_and_update_game_state(game_id, socket)}
  end

  def handle_event("update-coach-in-team", params, socket) do
    game_id = socket.assigns.game_state.result.id
    {:ok, event} = ValidatorCreator.validate_and_create("update-coach-in-team", game_id, params)

    {:noreply,
     event
     |> react_and_update_game_state(game_id, socket)}
  end

  def handle_event("update-player-in-team", params, socket) do
    game_id = socket.assigns.game_state.result.id
    {:ok, event} = ValidatorCreator.validate_and_create("update-player-in-team", game_id, params)

    {:noreply,
     event
     |> react_and_update_game_state(game_id, socket)}
  end

  def handle_event("update-clock-state", params, socket) do
    game_id = socket.assigns.game_state.result.id
    {:ok, event} = ValidatorCreator.validate_and_create("update-clock-state", game_id, params)

    {:noreply,
     event
     |> react_and_update_game_state(game_id, socket)}
  end

  def handle_event("add-coach-to-team", params, socket) do
    game_id = socket.assigns.game_state.result.id
    {:ok, event} = ValidatorCreator.validate_and_create("add-coach-to-team", game_id, params)

    {:noreply,
     event
     |> react_and_update_game_state(game_id, socket)}
  end

  def handle_event("add-official-to-game", params, socket) do
    game_id = socket.assigns.game_state.result.id
    {:ok, event} = ValidatorCreator.validate_and_create("add-official-to-game", game_id, params)

    {:noreply,
     event
     |> react_and_update_game_state(game_id, socket)}
  end

  def handle_event("add-player-to-team", params, socket) do
    game_id = socket.assigns.game_state.result.id
    {:ok, event} = ValidatorCreator.validate_and_create("add-player-to-team", game_id, params)

    {:noreply,
     event
     |> react_and_update_game_state(game_id, socket)}
  end

  def handle_event("remove-coach-in-team", params, socket) do
    game_id = socket.assigns.game_state.result.id
    {:ok, event} = ValidatorCreator.validate_and_create("remove-coach-in-team", game_id, params)

    {:noreply,
     event
     |> react_and_update_game_state(game_id, socket)}
  end

  def handle_event("remove-official-in-game", params, socket) do
    game_id = socket.assigns.game_state.result.id

    {:ok, event} =
      ValidatorCreator.validate_and_create("remove-official-in-game", game_id, params)

    {:noreply,
     event
     |> react_and_update_game_state(game_id, socket)}
  end

  def handle_event("remove-player-in-team", params, socket) do
    game_id = socket.assigns.game_state.result.id
    {:ok, event} = ValidatorCreator.validate_and_create("remove-player-in-team", game_id, params)

    {:noreply,
     event
     |> react_and_update_game_state(game_id, socket)}
  end

  def handle_event("substitute-player", params, socket) do
    game_id = socket.assigns.game_state.result.id
    {:ok, event} = ValidatorCreator.validate_and_create("substitute-player", game_id, params)

    {:noreply,
     event
     |> react_and_update_game_state(game_id, socket)}
  end

  def handle_event("update-clock-time-and-period", params, socket) do
    game_id = socket.assigns.game_state.result.id

    {:ok, event} =
      ValidatorCreator.validate_and_create("update-clock-time-and-period", game_id, params)

    {:noreply,
     event
     |> react_and_update_game_state(game_id, socket)}
  end

  def handle_event("update-official-in-game", params, socket) do
    game_id = socket.assigns.game_state.result.id

    {:ok, event} =
      ValidatorCreator.validate_and_create("update-official-in-game", game_id, params)

    {:noreply,
     event
     |> react_and_update_game_state(game_id, socket)}
  end

  def handle_event("update-team-metadata", params, socket) do
    game_id = socket.assigns.game_state.result.id

    {:ok, event} =
      ValidatorCreator.validate_and_create("update-team-metadata", game_id, params)

    {:noreply,
     event
     |> react_and_update_game_state(game_id, socket)}
  end

  def handle_event("end-game-live-mode", params, socket) do
    Games.end_live_mode(socket.assigns.game_state.result.id, params)

    {:noreply, socket}
  end

  def handle_event("start-game-live-mode", _, socket) do
    Games.start_live_mode(socket.assigns.game_state.result.id)

    {:noreply, socket}
  end

  def handle_event("register-team-wo", params, socket) do
    {:ok, event} =
      ValidatorCreator.validate_and_create(
        "register-team-wo",
        socket.assigns.game_state.result.id,
        params
      )

    {:noreply,
     event
     |> react_and_update_game_state(socket.assigns.game_state.result.id, socket)}
  end

  def handle_event("reset-game-live-mode", _, socket) do
    # TODO: Implement logic to reset game
    {:noreply, socket}
  end

  def handle_event("end-period", _, socket) do
    {:ok, event} =
      ValidatorCreator.validate_and_create("end-period", socket.assigns.game_state.result.id)

    {:noreply,
     event
     |> react_and_update_game_state(socket.assigns.game_state.result.id, socket)}
  end

  def handle_event("start-game", _, socket) do
    {:ok, event} =
      ValidatorCreator.validate_and_create("start-game", socket.assigns.game_state.result.id)

    {:noreply,
     event
     |> react_and_update_game_state(socket.assigns.game_state.result.id, socket)}
  end

  def handle_event("end-game", _, socket) do
    {:ok, event} =
      ValidatorCreator.validate_and_create("end-game", socket.assigns.game_state.result.id)

    {:noreply,
     event
     |> react_and_update_game_state(socket.assigns.game_state.result.id, socket)}
  end

  def handle_event("protest-game", params, socket) do
    {:ok, event} =
      ValidatorCreator.validate_and_create(
        "protest-game",
        socket.assigns.game_state.result.id,
        params
      )

    {:noreply,
     event
     |> react_and_update_game_state(socket.assigns.game_state.result.id, socket)}
  end

  def handle_event("update-game-info", params, socket) do
    {:ok, event} =
      ValidatorCreator.validate_and_create(
        "update-game-info",
        socket.assigns.game_state.result.id,
        params
      )

    {:noreply,
     event
     |> react_and_update_game_state(socket.assigns.game_state.result.id, socket)}
  end

  def handle_info(msg, socket) do
    case msg do
      {:game_reacted_to_event, %{game_state: game_state}} ->
        # React to the event and update the game state in the socket
        updated_socket =
          socket
          |> assign(:game_state, %{socket.assigns.game_state | result: game_state})

        {:noreply, updated_socket}

      {:game_event_logs_updated, %{game_id: _game_id, recent_events: recent_events}} ->
        # Handle the event logs update
        updated_socket =
          socket
          |> assign(:recent_events, %{result: recent_events})

        {:noreply, updated_socket}

      {:inactivity_timeout, tag} when tag == socket.assigns.inactivity_timer_tag ->
        game_id = socket.assigns.game_state.result.id

        if SnapshotStaleTracker.needs_rebuild?(game_id) do
          case EventLogs.rebuild_all_snapshots(game_id) do
            :ok ->
              PubSub.broadcast_game_last_snapshot_updated(game_id)

            {:error, reason} ->
              Logger.error(
                "[ScoreboardControlLive] Inactivity rebuild failed for game #{game_id}: #{inspect(reason)}"
              )
          end
        end

        {:noreply,
         socket
         |> assign(:inactivity_timer_ref, nil)
         |> assign(:inactivity_timer_tag, nil)}

      _ ->
        # Handle other messages if necessary
        {:noreply, socket}
    end
  end

  def handle_params(%{"game_id" => game_id}, _url, socket) do
    api_token = socket.assigns.api_token

    case ApiClient.get_game_for_operation(game_id, api_token) do
      {:error, reason} ->
        Logger.error("Failed to fetch game state: #{inspect(reason)}")

        {:noreply,
         push_navigate(socket,
           to: ~p"/error"
         )}

      {:ok, _game_state} ->
        {:noreply, socket}
    end
  end

  defp react_and_update_game_state(event, game_id, socket) do
    reacted_game_state = Games.react_to_event(event, game_id)

    if timer_ref = socket.assigns.inactivity_timer_ref do
      Process.cancel_timer(timer_ref)
    end

    tag = make_ref()
    timer_ref = Process.send_after(self(), {:inactivity_timeout, tag}, 30_000)

    socket
    |> assign(:game_state, %{socket.assigns.game_state | result: reacted_game_state})
    |> assign(:inactivity_timer_ref, timer_ref)
    |> assign(:inactivity_timer_tag, tag)
  end
end
