defmodule GoChampsScoreboard.Games.GamesTest do
  use ExUnit.Case
  alias GoChampsScoreboard.Events.Definitions.UpdateClockStateDefinition
  alias GoChampsScoreboard.Games.Games

  alias GoChampsScoreboard.Games.Models.{
    GameState,
    GameClockState,
    LiveState,
    OfficialState,
    TeamState
  }

  import Mox

  setup :verify_on_exit!

  @http_client GoChampsScoreboard.HTTPClientMock
  @resource_manager GoChampsScoreboard.Games.ResourceManagerMock

  describe "find_or_bootstrap/1 when game is set" do
    test "returns game_state" do
      game_state = set_test_game(:in_progress)

      result_game_state = Games.find_or_bootstrap(game_state.id)

      assert result_game_state.id == game_state.id
      assert result_game_state.away_team.name == "Some away team"
      assert result_game_state.home_team.name == "Some home team"

      unset_test_game(game_state.id)
    end

    test "returns bootstrapped game from go champs if current game is not_started" do
      game_state = set_test_game()
      # Let's say teams have been updated in Go Champs
      set_go_champs_api_respose(
        game_state.id,
        "Go champs updated away team",
        "Go champs updated home team"
      )

      set_go_champs_view_setting_api_response(game_state.id)

      result_game_state = Games.find_or_bootstrap(game_state.id, "token")

      {:ok, stored_game} = Redix.command(:games_cache, ["GET", "game_state:#{game_state.id}"])

      redis_game = GameState.from_json(stored_game)

      assert redis_game.id == game_state.id
      assert result_game_state.id == game_state.id
      assert result_game_state.away_team.name == "Go champs updated away team"
      assert result_game_state.home_team.name == "Go champs updated home team"

      unset_test_game(game_state.id)
    end

    test "return game from cache and restart resource manager if game is in progress" do
      game_state = set_test_game(:in_progress)

      expect(@resource_manager, :check_and_restart, fn game_id ->
        assert game_id == game_state.id

        :ok
      end)

      result_game_state = Games.find_or_bootstrap(game_state.id, "token", @resource_manager)

      assert result_game_state.id == game_state.id
      assert result_game_state.away_team.name == "Some away team"
      assert result_game_state.home_team.name == "Some home team"

      unset_test_game(game_state.id)
    end
  end

  describe "find_or_bootstrap/1 when game is not set" do
    test "bootstraps game from go champs, store it and returns it" do
      set_go_champs_api_respose()
      set_go_champs_view_setting_api_response()

      result_game_state = Games.find_or_bootstrap("some-game-id", "token")

      {:ok, stored_game} = Redix.command(:games_cache, ["GET", "game_state:some-game-id"])

      redis_game = GameState.from_json(stored_game)

      assert redis_game.id == "some-game-id"
      assert result_game_state.id == "some-game-id"
      assert result_game_state.away_team.name == "Go champs away team"
      assert result_game_state.home_team.name == "Go champs home team"

      unset_test_game("some-game-id")
    end
  end

  describe "start_live_mode/1" do
    test "starts up ResourceManager and returns a handled StartGameLiveMode game state" do
      game_state = set_test_game()

      expect(@resource_manager, :start_up, fn game_id ->
        assert game_id == game_state.id
        :ok
      end)

      result_game = Games.start_live_mode(game_state.id, @resource_manager)

      assert result_game.live_state.state == :in_progress

      unset_test_game(game_state.id)
    end
  end

  describe "end_live_mode/1" do
    test "shuts down ResourceManager and returns a handled EndGameLiveMode game state" do
      game_state = set_test_game()

      expect(@resource_manager, :shut_down, fn game_id ->
        assert game_id == game_state.id
        :ok
      end)

      result_game = Games.end_live_mode(game_state.id, %{}, @resource_manager)

      assert result_game.live_state.state == :ended

      unset_test_game(game_state.id)
    end

    test "with assets in params, adds assets to game info" do
      game_state = set_test_game()

      expect(@resource_manager, :shut_down, fn game_id ->
        assert game_id == game_state.id
        :ok
      end)

      params = %{
        "assets" => [
          %{"type" => "logo", "url" => "http://example.com/logo1.png"},
          %{"type" => "banner", "url" => "http://example.com/banner1.png"}
        ]
      }

      result_game = Games.end_live_mode(game_state.id, params, @resource_manager)

      assert result_game.live_state.state == :ended

      assert Enum.any?(result_game.info.assets, fn asset ->
               asset.type == "logo" and asset.url == "http://example.com/logo1.png"
             end)

      assert Enum.any?(result_game.info.assets, fn asset ->
               asset.type == "banner" and asset.url == "http://example.com/banner1.png"
             end)

      unset_test_game(game_state.id)
    end
  end

  describe "react_to_event/2 for started game" do
    test "when UpdateClockState event is given, returns a game handled by the event" do
      game_state = set_test_game()

      event = UpdateClockStateDefinition.create(game_state.id, 10, 1, %{"state" => "running"})
      handled_game = get_test_game(game_state.id) |> UpdateClockStateDefinition.handle(event)

      result_game_state = Games.react_to_event(event, game_state.id)

      assert result_game_state.clock_state.state == handled_game.clock_state.state

      unset_test_game(game_state.id)
    end
  end

  describe "update_team" do
    test "return a game state with given updated team" do
      game_state = %GameState{
        id: "some-game-id",
        away_team: %TeamState{name: "Some away team"},
        home_team: %TeamState{name: "Some home team"}
      }

      updated_team = %TeamState{name: "Updated home team"}

      result_game_state = Games.update_team(game_state, "home", updated_team)

      assert result_game_state.id == "some-game-id"
      assert result_game_state.away_team.name == "Some away team"
      assert result_game_state.home_team.name == "Updated home team"
    end
  end

  describe "update_clock_state" do
    test "return a game state with given updated clock state" do
      game_state = %GameState{
        id: "some-game-id",
        away_team: %TeamState{name: "Some away team"},
        home_team: %TeamState{name: "Some home team"},
        clock_state: %GameClockState{time: 10, period: 1, state: :running}
      }

      updated_clock_state = %GameClockState{time: 9, period: 1, state: :running}

      result_game_state = Games.update_clock_state(game_state, updated_clock_state)

      assert result_game_state.id == "some-game-id"
      assert result_game_state.away_team.name == "Some away team"
      assert result_game_state.home_team.name == "Some home team"
      assert result_game_state.clock_state.time == 9
      assert result_game_state.clock_state.period == 1
      assert result_game_state.clock_state.state == :running
    end
  end

  describe "add_official/2" do
    test "adds an official to the game state" do
      game_state = %GameState{
        id: "some-game-id",
        away_team: %TeamState{name: "Some away team"},
        home_team: %TeamState{name: "Some home team"},
        officials: []
      }

      official = %OfficialState{id: "some-id", type: :crew_chief, name: "John Doe"}

      result_game_state = Games.add_official(game_state, official)

      assert result_game_state.id == "some-game-id"
      assert length(result_game_state.officials) == 1
      assert result_game_state.officials |> hd() == official
    end
  end

  describe "remove_official_by_id_and_type/2" do
    test "removes an official from the game state" do
      official = %OfficialState{id: "some-id", type: :crew_chief, name: "John Doe"}

      game_state = %GameState{
        id: "some-game-id",
        away_team: %TeamState{name: "Some away team"},
        home_team: %TeamState{name: "Some home team"},
        officials: [official]
      }

      result_game_state =
        Games.remove_official_by_id_and_type(game_state, official.id, official.type)

      assert result_game_state.id == "some-game-id"
      assert length(result_game_state.officials) == 0
    end
  end

  describe "update_official_by_id_and_type/2" do
    test "updates an official in the game state" do
      official = %OfficialState{id: "some-id", type: :crew_chief, name: "John Doe"}

      game_state = %GameState{
        id: "some-game-id",
        away_team: %TeamState{name: "Some away team"},
        home_team: %TeamState{name: "Some home team"},
        officials: [official]
      }

      updated_official = %OfficialState{
        id: "some-id",
        type: :crew_chief,
        name: "Ben John"
      }

      result_game_state = Games.update_official_by_id_and_type(game_state, updated_official)

      assert result_game_state.id == "some-game-id"
      assert length(result_game_state.officials) == 1
      assert result_game_state.officials |> hd() == updated_official
    end
  end

  describe "update_protest_state/2" do
    test "updates the protest state in the game state" do
      game_state = %GameState{
        id: "some-game-id",
        away_team: %TeamState{name: "Some away team"},
        home_team: %TeamState{name: "Some home team"},
        protest: %GoChampsScoreboard.Games.Models.ProtestState{
          team_type: :none,
          player_id: "",
          state: :no_protest
        }
      }

      updated_protest_state = %GoChampsScoreboard.Games.Models.ProtestState{
        team_type: :home,
        player_id: "player-456",
        state: :protest_filed
      }

      result_game_state = Games.update_protest_state(game_state, updated_protest_state)

      assert result_game_state.id == "some-game-id"
      assert result_game_state.protest == updated_protest_state
    end
  end

  defp set_go_champs_api_respose(
         game_id \\ "some-game-id",
         away_team_name \\ "Go champs away team",
         home_team_name \\ "Go champs home team"
       ) do
    response_body = %{
      "data" => %{
        "id" => game_id,
        "meta" => %{"permissions" => ["game:operate"]},
        "away_team" => %{
          "name" => away_team_name
        },
        "home_team" => %{
          "name" => home_team_name
        }
      }
    }

    expect(@http_client, :get, fn url, headers, _opts ->
      assert url =~ game_id
      assert headers == [{"Authorization", "Bearer token"}]

      {:ok, %HTTPoison.Response{body: response_body |> Poison.encode!(), status_code: 200}}
    end)
  end

  defp set_go_champs_view_setting_api_response(game_id \\ "some-game-id") do
    response_body = %{
      "data" => nil
    }

    expect(@http_client, :get, fn url, _headers, _opts ->
      assert url =~ "#{game_id}/scoreboard-setting"

      {:ok, %HTTPoison.Response{body: response_body |> Poison.encode!(), status_code: 200}}
    end)
  end

  defp set_test_game(live_state \\ :not_started) do
    away_team = TeamState.new(Ecto.UUID.generate(), "Some away team")
    home_team = TeamState.new(Ecto.UUID.generate(), "Some home team")
    clock_state = GameClockState.new()
    live_state = LiveState.new(live_state)

    game_state =
      GameState.new(Ecto.UUID.generate(), away_team, home_team, clock_state, live_state)

    Redix.command(:games_cache, ["SET", "game_state:#{game_state.id}", game_state])

    game_state
  end

  defp unset_test_game(game_id) do
    Redix.command(:games_cache, ["DEL", "game_state:#{game_id}"])
  end

  defp get_test_game(game_id) do
    {:ok, game_json} = Redix.command(:games_cache, ["GET", "game_state:#{game_id}"])
    GameState.from_json(game_json)
  end

  describe "update_info/2" do
    test "updates game state with new info" do
      alias GoChampsScoreboard.Games.Models.InfoState

      original_datetime = DateTime.utc_now()

      game_state = %GameState{
        id: "game-id",
        info: %InfoState{
          datetime: original_datetime,
          tournament_id: "tournament-1",
          tournament_name: "Tournament Name",
          location: "Old Stadium",
          number: "OLD123"
        }
      }

      new_info = %InfoState{
        datetime: original_datetime,
        tournament_id: "tournament-1",
        tournament_name: "Tournament Name",
        location: "New Stadium",
        number: "NEW456"
      }

      updated_game_state = Games.update_info(game_state, new_info)

      assert updated_game_state.info == new_info
      assert updated_game_state.id == "game-id"
    end

    test "completely replaces info state" do
      alias GoChampsScoreboard.Games.Models.InfoState

      original_datetime = DateTime.utc_now()
      new_datetime = DateTime.add(original_datetime, 3600)

      game_state = %GameState{
        id: "game-id",
        info: %InfoState{
          datetime: original_datetime,
          tournament_id: "old-tournament",
          tournament_name: "Old Tournament",
          location: "Old Stadium",
          number: "OLD123"
        }
      }

      new_info = %InfoState{
        datetime: new_datetime,
        tournament_id: "new-tournament",
        tournament_name: "New Tournament",
        location: "New Stadium",
        number: "NEW456"
      }

      updated_game_state = Games.update_info(game_state, new_info)

      assert updated_game_state.info.datetime == new_datetime
      assert updated_game_state.info.tournament_id == "new-tournament"
      assert updated_game_state.info.tournament_name == "New Tournament"
      assert updated_game_state.info.location == "New Stadium"
      assert updated_game_state.info.number == "NEW456"
    end
  end

  describe "update_game_level_player_stats/6" do
    test "returns unchanged game state when game_level_stats is empty" do
      alias GoChampsScoreboard.Games.Models.PlayerState

      player1 = PlayerState.new("player-1", "Player 1", 10)
      player2 = PlayerState.new("player-2", "Player 2", 20)

      home_team = %TeamState{
        name: "Home Team",
        players: [player1, player2]
      }

      away_team = %TeamState{
        name: "Away Team",
        players: []
      }

      game_state = %GameState{
        id: "game-id",
        home_team: home_team,
        away_team: away_team,
        sport_id: "basketball"
      }

      result =
        Games.update_game_level_player_stats(
          game_state,
          "home",
          [],
          "field_goals_made",
          "increment",
          "home"
        )

      assert result == game_state
    end

    test "updates home team players with game-level stats when home team scores" do
      alias GoChampsScoreboard.Games.Models.PlayerState
      alias GoChampsScoreboard.Statistics.Models.Stat
      alias GoChampsScoreboard.Sports.Basketball.Statistics

      # Create players - player1 is playing, player2 is on bench
      player1 = %PlayerState{
        id: "player-1",
        name: "Player 1",
        number: 10,
        state: :playing,
        stats_values: %{
          "plus_minus" => 0
        }
      }

      player2 = %PlayerState{
        id: "player-2",
        name: "Player 2",
        number: 20,
        state: :bench,
        stats_values: %{
          "plus_minus" => 5
        }
      }

      home_team = %TeamState{
        name: "Home Team",
        players: [player1, player2]
      }

      away_team = %TeamState{
        name: "Away Team",
        players: []
      }

      game_state = %GameState{
        id: "game-id",
        home_team: home_team,
        away_team: away_team,
        sport_id: "basketball"
      }

      # Create game-level stat (plus_minus)
      plus_minus_stat =
        Stat.new("plus_minus", :calculated, [], &Statistics.calc_player_plus_minus/6, :game)

      result =
        Games.update_game_level_player_stats(
          game_state,
          "home",
          [plus_minus_stat],
          "field_goals_made",
          "increment",
          "home"
        )

      # Find updated players
      updated_player1 = Enum.find(result.home_team.players, fn p -> p.id == "player-1" end)
      updated_player2 = Enum.find(result.home_team.players, fn p -> p.id == "player-2" end)

      # Player 1 is playing and home team scored a field goal (+2)
      assert updated_player1.stats_values["plus_minus"] == 2

      # Player 2 is on bench, plus_minus should remain unchanged
      assert updated_player2.stats_values["plus_minus"] == 5
    end

    test "updates away team players with game-level stats when away team scores" do
      alias GoChampsScoreboard.Games.Models.PlayerState
      alias GoChampsScoreboard.Statistics.Models.Stat
      alias GoChampsScoreboard.Sports.Basketball.Statistics

      player1 = %PlayerState{
        id: "player-1",
        name: "Player 1",
        number: 10,
        state: :playing,
        stats_values: %{
          "plus_minus" => 3
        }
      }

      home_team = %TeamState{
        name: "Home Team",
        players: []
      }

      away_team = %TeamState{
        name: "Away Team",
        players: [player1]
      }

      game_state = %GameState{
        id: "game-id",
        home_team: home_team,
        away_team: away_team,
        sport_id: "basketball"
      }

      plus_minus_stat =
        Stat.new("plus_minus", :calculated, [], &Statistics.calc_player_plus_minus/6, :game)

      result =
        Games.update_game_level_player_stats(
          game_state,
          "away",
          [plus_minus_stat],
          "three_point_field_goals_made",
          "increment",
          "away"
        )

      updated_player1 = Enum.find(result.away_team.players, fn p -> p.id == "player-1" end)

      # Away team scored a three-pointer (+3), so plus_minus goes from 3 to 6
      assert updated_player1.stats_values["plus_minus"] == 6
    end

    test "updates home team players negatively when away team scores" do
      alias GoChampsScoreboard.Games.Models.PlayerState
      alias GoChampsScoreboard.Statistics.Models.Stat
      alias GoChampsScoreboard.Sports.Basketball.Statistics

      player1 = %PlayerState{
        id: "player-1",
        name: "Player 1",
        number: 10,
        state: :playing,
        stats_values: %{
          "plus_minus" => 5
        }
      }

      home_team = %TeamState{
        name: "Home Team",
        players: [player1]
      }

      away_team = %TeamState{
        name: "Away Team",
        players: []
      }

      game_state = %GameState{
        id: "game-id",
        home_team: home_team,
        away_team: away_team,
        sport_id: "basketball"
      }

      plus_minus_stat =
        Stat.new("plus_minus", :calculated, [], &Statistics.calc_player_plus_minus/6, :game)

      # Home team player stats updated when away team scores
      result =
        Games.update_game_level_player_stats(
          game_state,
          "home",
          [plus_minus_stat],
          "field_goals_made",
          "increment",
          "away"
        )

      updated_player1 = Enum.find(result.home_team.players, fn p -> p.id == "player-1" end)

      # Away team scored a field goal, so home player's plus_minus decreases by 2 (5 - 2 = 3)
      assert updated_player1.stats_values["plus_minus"] == 3
    end

    test "handles decrement operation correctly" do
      alias GoChampsScoreboard.Games.Models.PlayerState
      alias GoChampsScoreboard.Statistics.Models.Stat
      alias GoChampsScoreboard.Sports.Basketball.Statistics

      player1 = %PlayerState{
        id: "player-1",
        name: "Player 1",
        number: 10,
        state: :playing,
        stats_values: %{
          "plus_minus" => 10
        }
      }

      home_team = %TeamState{
        name: "Home Team",
        players: [player1]
      }

      away_team = %TeamState{
        name: "Away Team",
        players: []
      }

      game_state = %GameState{
        id: "game-id",
        home_team: home_team,
        away_team: away_team,
        sport_id: "basketball"
      }

      plus_minus_stat =
        Stat.new("plus_minus", :calculated, [], &Statistics.calc_player_plus_minus/6, :game)

      # Decrement a field goal for home team (undo scoring)
      result =
        Games.update_game_level_player_stats(
          game_state,
          "home",
          [plus_minus_stat],
          "field_goals_made",
          "decrement",
          "home"
        )

      updated_player1 = Enum.find(result.home_team.players, fn p -> p.id == "player-1" end)

      # Decrementing own team's field goal: 10 - 2 = 8
      assert updated_player1.stats_values["plus_minus"] == 8
    end

    test "updates multiple players on the same team" do
      alias GoChampsScoreboard.Games.Models.PlayerState
      alias GoChampsScoreboard.Statistics.Models.Stat
      alias GoChampsScoreboard.Sports.Basketball.Statistics

      player1 = %PlayerState{
        id: "player-1",
        name: "Player 1",
        number: 10,
        state: :playing,
        stats_values: %{
          "plus_minus" => 2
        }
      }

      player2 = %PlayerState{
        id: "player-2",
        name: "Player 2",
        number: 20,
        state: :playing,
        stats_values: %{
          "plus_minus" => -3
        }
      }

      player3 = %PlayerState{
        id: "player-3",
        name: "Player 3",
        number: 30,
        state: :bench,
        stats_values: %{
          "plus_minus" => 0
        }
      }

      home_team = %TeamState{
        name: "Home Team",
        players: [player1, player2, player3]
      }

      away_team = %TeamState{
        name: "Away Team",
        players: []
      }

      game_state = %GameState{
        id: "game-id",
        home_team: home_team,
        away_team: away_team,
        sport_id: "basketball"
      }

      plus_minus_stat =
        Stat.new("plus_minus", :calculated, [], &Statistics.calc_player_plus_minus/6, :game)

      result =
        Games.update_game_level_player_stats(
          game_state,
          "home",
          [plus_minus_stat],
          "free_throws_made",
          "increment",
          "home"
        )

      updated_player1 = Enum.find(result.home_team.players, fn p -> p.id == "player-1" end)
      updated_player2 = Enum.find(result.home_team.players, fn p -> p.id == "player-2" end)
      updated_player3 = Enum.find(result.home_team.players, fn p -> p.id == "player-3" end)

      # Both playing players get +1 for free throw
      assert updated_player1.stats_values["plus_minus"] == 3
      assert updated_player2.stats_values["plus_minus"] == -2

      # Bench player unchanged
      assert updated_player3.stats_values["plus_minus"] == 0
    end

    test "recalculates team total player stats after updating game-level stats" do
      alias GoChampsScoreboard.Games.Models.PlayerState
      alias GoChampsScoreboard.Statistics.Models.Stat
      alias GoChampsScoreboard.Sports.Basketball.Statistics

      # Create players with existing stats including plus_minus
      player1 = %PlayerState{
        id: "player-1",
        name: "Player 1",
        number: 10,
        state: :playing,
        stats_values: %{
          "plus_minus" => 0,
          "points" => 10,
          "rebounds_total" => 5
        }
      }

      player2 = %PlayerState{
        id: "player-2",
        name: "Player 2",
        number: 20,
        state: :playing,
        stats_values: %{
          "plus_minus" => 3,
          "points" => 15,
          "rebounds_total" => 8
        }
      }

      home_team = %TeamState{
        name: "Home Team",
        players: [player1, player2],
        total_player_stats: %{
          "plus_minus" => 3,
          "points" => 25,
          "rebounds_total" => 13
        }
      }

      away_team = %TeamState{
        name: "Away Team",
        players: []
      }

      game_state = %GameState{
        id: "game-id",
        home_team: home_team,
        away_team: away_team,
        sport_id: "basketball"
      }

      plus_minus_stat =
        Stat.new("plus_minus", :calculated, [], &Statistics.calc_player_plus_minus/6, :game)

      # Home team scores a field goal (+2 for each playing player)
      result =
        Games.update_game_level_player_stats(
          game_state,
          "home",
          [plus_minus_stat],
          "field_goals_made",
          "increment",
          "home"
        )

      # Verify individual player stats were updated
      updated_player1 = Enum.find(result.home_team.players, fn p -> p.id == "player-1" end)
      updated_player2 = Enum.find(result.home_team.players, fn p -> p.id == "player-2" end)

      assert updated_player1.stats_values["plus_minus"] == 2
      assert updated_player2.stats_values["plus_minus"] == 5

      # Verify team total player stats were recalculated
      assert result.home_team.total_player_stats["plus_minus"] == 7
      assert result.home_team.total_player_stats["points"] == 25
      assert result.home_team.total_player_stats["rebounds_total"] == 13
    end

    test "team total player stats includes all player stats after game-level stat update" do
      alias GoChampsScoreboard.Games.Models.PlayerState
      alias GoChampsScoreboard.Statistics.Models.Stat
      alias GoChampsScoreboard.Sports.Basketball.Statistics

      player1 = %PlayerState{
        id: "player-1",
        name: "Player 1",
        number: 10,
        state: :playing,
        stats_values: %{
          "plus_minus" => 5,
          "assists" => 3,
          "steals" => 2
        }
      }

      player2 = %PlayerState{
        id: "player-2",
        name: "Player 2",
        number: 20,
        state: :bench,
        stats_values: %{
          "plus_minus" => -2,
          "assists" => 1,
          "steals" => 0
        }
      }

      player3 = %PlayerState{
        id: "player-3",
        name: "Player 3",
        number: 30,
        state: :playing,
        stats_values: %{
          "plus_minus" => 0,
          "assists" => 5,
          "steals" => 1
        }
      }

      away_team = %TeamState{
        name: "Away Team",
        players: [player1, player2, player3],
        total_player_stats: %{}
      }

      home_team = %TeamState{
        name: "Home Team",
        players: []
      }

      game_state = %GameState{
        id: "game-id",
        home_team: home_team,
        away_team: away_team,
        sport_id: "basketball"
      }

      plus_minus_stat =
        Stat.new("plus_minus", :calculated, [], &Statistics.calc_player_plus_minus/6, :game)

      # Away team scores a three-pointer (+3 for playing players)
      result =
        Games.update_game_level_player_stats(
          game_state,
          "away",
          [plus_minus_stat],
          "three_point_field_goals_made",
          "increment",
          "away"
        )

      # Player1 (playing): 5 + 3 = 8
      # Player2 (bench): -2 (unchanged)
      # Player3 (playing): 0 + 3 = 3
      # Total: 8 + (-2) + 3 = 9

      assert result.away_team.total_player_stats["plus_minus"] == 9
      assert result.away_team.total_player_stats["assists"] == 9
      assert result.away_team.total_player_stats["steals"] == 3
    end

    test "team total player stats correctly updated when opponent scores" do
      alias GoChampsScoreboard.Games.Models.PlayerState
      alias GoChampsScoreboard.Statistics.Models.Stat
      alias GoChampsScoreboard.Sports.Basketball.Statistics

      player1 = %PlayerState{
        id: "player-1",
        name: "Player 1",
        number: 10,
        state: :playing,
        stats_values: %{
          "plus_minus" => 10,
          "field_goals_made" => 5
        }
      }

      player2 = %PlayerState{
        id: "player-2",
        name: "Player 2",
        number: 20,
        state: :playing,
        stats_values: %{
          "plus_minus" => 8,
          "field_goals_made" => 3
        }
      }

      home_team = %TeamState{
        name: "Home Team",
        players: [player1, player2],
        total_player_stats: %{
          "plus_minus" => 18,
          "field_goals_made" => 8
        }
      }

      away_team = %TeamState{
        name: "Away Team",
        players: []
      }

      game_state = %GameState{
        id: "game-id",
        home_team: home_team,
        away_team: away_team,
        sport_id: "basketball"
      }

      plus_minus_stat =
        Stat.new("plus_minus", :calculated, [], &Statistics.calc_player_plus_minus/6, :game)

      # Away team scores a field goal (-2 for each home playing player)
      result =
        Games.update_game_level_player_stats(
          game_state,
          "home",
          [plus_minus_stat],
          "field_goals_made",
          "increment",
          "away"
        )

      # Player1: 10 - 2 = 8
      # Player2: 8 - 2 = 6
      # Total: 8 + 6 = 14

      assert result.home_team.total_player_stats["plus_minus"] == 14
      assert result.home_team.total_player_stats["field_goals_made"] == 8
    end
  end
end
