defmodule GoChampsScoreboard.Games.Bootstrapper do
  require Logger
  alias GoChampsScoreboard.Games.Models.LiveState
  alias GoChampsScoreboard.ApiClient
  alias GoChampsScoreboard.Games.Models.CoachState
  alias GoChampsScoreboard.Games.Models.GameClockState
  alias GoChampsScoreboard.Games.Models.GameState
  alias GoChampsScoreboard.Games.Models.PlayerState
  alias GoChampsScoreboard.Games.Models.TeamState
  alias GoChampsScoreboard.Games.Models.ViewSettingsState
  alias GoChampsScoreboard.Games.Models.InfoState
  alias GoChampsScoreboard.Games.Models.ProtestState
  alias GoChampsScoreboard.Games.Models.OfficialState
  alias GoChampsScoreboard.Sports

  @mock_initial_period_time 600
  @mock_initial_extra_period_time 300
  @mock_sport_slug "basketball"

  @spec bootstrap() :: GameState.t()
  def bootstrap() do
    home_team = TeamState.new(Ecto.UUID.generate(), "Home team")
    away_team = TeamState.new(Ecto.UUID.generate(), "Away team")
    clock_state = GameClockState.new()
    game_id = Ecto.UUID.generate()
    live_state = LiveState.new()

    GameState.new(game_id, away_team, home_team, clock_state, live_state)
  end

  def bootstrap_from_go_champs(game, game_id, token) do
    with {:ok, game_response} <- ApiClient.get_game_for_operation(game_id, token),
         {:ok, view_settings_response} <- ApiClient.get_scoreboard_setting(game_id) do
      game
      |> map_game_response_to_game(game_response, view_settings_response)
    else
      {:error, reason} ->
        Logger.error("Failed to bootstrap game #{game_id} from Go Champs API: #{inspect(reason)}")

        game
    end
  end

  defp map_game_response_to_game(game_state, game_data, view_settings_data) do
    game_response = game_data["data"]
    away_team = map_api_team_to_team(game_response["away_team"])
    home_team = map_api_team_to_team(game_response["home_team"])

    game_id = Map.get(game_response, "id", game_state.id)

    clock_state = map_clock_state(view_settings_data["data"])

    live_state = map_live_state(game_response["live_state"])

    view_settings_state = map_view_settings_state(view_settings_data["data"])

    info = map_info_state(game_response)

    officials = map_api_officials_to_officials(game_response, @mock_sport_slug)

    GameState.new(
      game_id,
      away_team,
      home_team,
      clock_state,
      live_state,
      @mock_sport_slug,
      view_settings_state,
      officials,
      ProtestState.new("", "", :no_protest),
      info
    )
  end

  defp map_api_team_to_team(team) do
    id = Map.get(team, "id") || Ecto.UUID.generate()
    name = Map.get(team, "name", "No team")
    logo_url = Map.get(team, "logo_url", "")
    tri_code = Map.get(team, "tri_code", "")
    primary_color = Map.get(team, "primary_color", nil)
    players = map_team_players_to_players(team)
    coaches = map_team_coaches_to_coaches(team)

    TeamState.new(
      id,
      name,
      players,
      %{},
      nil,
      tri_code,
      logo_url,
      coaches,
      %{},
      primary_color
    )
  end

  defp map_team_players_to_players(team) do
    team_players = Map.get(team, "players", [])

    Enum.map(team_players, fn player ->
      name = Map.get(player, "shirt_name") || Map.get(player, "name") || "No name"

      state =
        Map.get(player, "state", "available")
        |> String.to_atom()

      PlayerState.new(player["id"], name, player["shirt_number"], player["license_number"], state)
    end)
  end

  defp map_team_coaches_to_coaches(team) do
    team_coaches = Map.get(team, "coaches", [])

    Enum.map(team_coaches, fn coach ->
      name = Map.get(coach, "name", "No name")
      type = Map.get(coach, "type", "head_coach") |> String.to_atom()
      state = Map.get(coach, "state", "available") |> String.to_atom()

      CoachState.new(
        coach["id"],
        name,
        type,
        state
      )
    end)
  end

  defp map_api_officials_to_officials(game_response, sport_id) do
    api_officials = Map.get(game_response, "officials", [])
    default_officials = Sports.Sports.bootstrap_officials(sport_id)

    case api_officials do
      [] ->
        default_officials

      nil ->
        default_officials

      officials when is_list(officials) ->
        merge_officials_with_defaults(officials, default_officials)
    end
  end

  defp merge_officials_with_defaults(api_officials, default_officials) do
    # Create a map of API officials by type for efficient lookup
    api_officials_by_type =
      api_officials
      |> Enum.map(&map_api_official_to_official/1)
      # Remove invalid officials
      |> Enum.filter(&(&1 != nil))
      |> Enum.group_by(& &1.type)
      |> Enum.map(fn {type, officials} -> {type, List.first(officials)} end)
      |> Map.new()

    # Replace defaults with API officials where available, maintaining order
    Enum.map(default_officials, fn default_official ->
      case Map.get(api_officials_by_type, default_official.type) do
        nil -> default_official
        api_official -> api_official
      end
    end)
  end

  defp map_api_official_to_official(api_official) do
    official_data = Map.get(api_official, "official", %{})
    official_id = Map.get(api_official, "official_id", "")
    role = Map.get(api_official, "role", "")
    name = Map.get(official_data, "name", "")
    license_number = Map.get(official_data, "license_number")
    federation = Map.get(official_data, "federation")
    username = Map.get(official_data, "username")

    case map_role_to_type(role) do
      {:ok, type} ->
        OfficialState.new(
          official_id,
          name,
          type,
          license_number,
          federation,
          # signature
          nil,
          username
        )

      {:error, _} ->
        Logger.warning("Invalid official role received from API: #{role}")
        nil
    end
  end

  defp map_role_to_type(role) when is_binary(role) do
    case role do
      "referee" -> {:ok, :crew_chief}
      "crew_chief" -> {:ok, :crew_chief}
      "umpire_1" -> {:ok, :umpire_1}
      "umpire_2" -> {:ok, :umpire_2}
      "scorer" -> {:ok, :scorer}
      "assistant_scorer" -> {:ok, :assistant_scorer}
      "timekeeper" -> {:ok, :timekeeper}
      "shot_clock_operator" -> {:ok, :shot_clock_operator}
      _ -> {:error, :invalid_role}
    end
  end

  defp map_role_to_type(_), do: {:error, :invalid_role}

  defp map_live_state(live_state) do
    case live_state do
      "not_started" -> LiveState.new(:not_started)
      "in_progress" -> LiveState.new(:in_progress)
      "ended" -> LiveState.new(:ended)
      _ -> LiveState.new(:not_started)
    end
  end

  def map_view_settings_state(view_settings_data) do
    case view_settings_data do
      nil ->
        ViewSettingsState.new()

      data ->
        available_views = Map.get(data, "available_views", [])

        # Determine view based on available_views
        view =
          case available_views do
            # If only one view available, use it
            [single_view] ->
              single_view

            # If multiple views available
            [_ | _] = views ->
              # Check if basketball-medium-stats-plus-scoresheet is in the array
              if "basketball-medium-stats-plus-scoresheet" in views do
                "basketball-medium-stats-plus-scoresheet"
              else
                # Otherwise use the first one
                List.first(views)
              end

            # If no available_views, fall back to default or provided view
            [] ->
              Map.get(data, "view", "basketball-medium-stats")
          end

        ViewSettingsState.new(view, available_views)
    end
  end

  defp map_clock_state(view_settings_data) do
    case view_settings_data do
      nil ->
        GameClockState.new(
          @mock_initial_period_time,
          @mock_initial_extra_period_time,
          @mock_initial_period_time
        )

      data ->
        initial_period_time = Map.get(data, "initial_period_time", @mock_initial_period_time)

        initial_extra_period_time =
          Map.get(data, "initial_extra_period_time", @mock_initial_extra_period_time)

        GameClockState.new(
          initial_period_time,
          initial_extra_period_time,
          initial_period_time
        )
    end
  end

  defp map_info_state(game_response) do
    datetime_str = Map.get(game_response, "datetime")

    datetime =
      if datetime_str do
        case DateTime.from_iso8601(datetime_str) do
          {:ok, parsed_datetime, _} -> parsed_datetime
          {:error, _} -> DateTime.utc_now()
        end
      else
        nil
      end

    location = Map.get(game_response, "location", "")
    city = Map.get(game_response, "city", "")
    game_id = Map.get(game_response, "id", "")
    number = Map.get(game_response, "number")
    web_url = Map.get(game_response, "web_url", "")
    tournament_info = get_in(game_response, ["phase", "tournament"]) || %{}
    tournament_id = Map.get(tournament_info, "id", "")
    tournament_name = Map.get(tournament_info, "name", "")
    tournament_slug = Map.get(tournament_info, "slug", "")
    tournament_logo_url = Map.get(tournament_info, "logo_url", "")

    organization_info = Map.get(tournament_info, "organization", %{})
    organization_name = Map.get(organization_info, "name", "")
    organization_slug = Map.get(organization_info, "slug", "")
    organization_logo_url = Map.get(organization_info, "logo_url", "")

    sponsors = map_sponsors(Map.get(tournament_info, "sponsors", []))

    # Use number field if present and not empty/nil, otherwise fall back to game_id
    game_number =
      case number do
        nil -> game_id
        "" -> game_id
        valid_number -> valid_number
      end

    InfoState.new(
      datetime,
      tournament_id: tournament_id,
      tournament_name: tournament_name,
      tournament_slug: tournament_slug,
      tournament_logo_url: tournament_logo_url,
      organization_name: organization_name,
      organization_slug: organization_slug,
      organization_logo_url: organization_logo_url,
      location: location,
      city: city,
      number: game_number,
      web_url: web_url,
      sponsors: sponsors
    )
  end

  defp map_sponsors(sponsors) when is_list(sponsors) do
    Enum.map(sponsors, fn sponsor ->
      %{
        name: Map.get(sponsor, "name", ""),
        link: Map.get(sponsor, "link", ""),
        logo_url: Map.get(sponsor, "logo_url", "")
      }
    end)
  end

  defp map_sponsors(_), do: []
end
