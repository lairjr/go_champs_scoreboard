defmodule GoChampsScoreboard.Sports.Basketball.Reports.FibaScoresheet.EndPeriodProcessorTest do
  use ExUnit.Case
  use GoChampsScoreboard.DataCase

  alias GoChampsScoreboard.Sports.Basketball.Reports.FibaScoresheet.TeamManager
  alias GoChampsScoreboard.Sports.Basketball.Reports.FibaScoresheet.FibaScoresheetManager
  alias GoChampsScoreboard.Sports.Basketball.Reports.FibaScoresheet.EndPeriodProcessor
  alias GoChampsScoreboard.Sports.Basketball.Reports.FibaScoresheet
  alias GoChampsScoreboard.Games.EventLogs

  import GoChampsScoreboard.GameStateFixtures
  import GoChampsScoreboard.FibaScoresheetFixtures

  describe "process/2" do
    test "returns a fiba scoresheet data with current point score marked as last of period" do
      game_state = basketball_game_state_fixture()

      event =
        GoChampsScoreboard.Events.Definitions.EndPeriodDefinition.create(
          game_state.id,
          0,
          1,
          %{}
        )

      updated_game_state = GoChampsScoreboard.Events.Handler.handle(game_state, event)

      {:ok, event_log} = EventLogs.persist(event, updated_game_state)

      team_a_players = [
        %FibaScoresheet.Player{id: "123", name: "Player 1", number: 12, fouls: []}
      ]

      team_b_players = [
        %FibaScoresheet.Player{id: "456", name: "Player 2", number: 23, fouls: []}
      ]

      fiba_scoresheet =
        fiba_scoresheet_fixture(
          game_id: event_log.game_id,
          team_a_players: team_a_players,
          team_b_players: team_b_players
        )

      # 10 points in total
      updated_team_a =
        fiba_scoresheet
        |> FibaScoresheetManager.find_team("home")
        |> TeamManager.add_score(%FibaScoresheet.PointScore{
          type: "2PT",
          player_number: 12,
          period: 1,
          is_last_of_period: false
        })
        |> TeamManager.add_score(%FibaScoresheet.PointScore{
          type: "2PT",
          player_number: 12,
          period: 1,
          is_last_of_period: false
        })
        |> TeamManager.add_score(%FibaScoresheet.PointScore{
          type: "2PT",
          player_number: 12,
          period: 1,
          is_last_of_period: false
        })
        |> TeamManager.add_score(%FibaScoresheet.PointScore{
          type: "2PT",
          player_number: 12,
          period: 1,
          is_last_of_period: false
        })
        |> TeamManager.add_score(%FibaScoresheet.PointScore{
          type: "2PT",
          player_number: 12,
          period: 1,
          is_last_of_period: false
        })

      # 6 Points in total
      updated_team_b =
        fiba_scoresheet
        |> FibaScoresheetManager.find_team("away")
        |> TeamManager.add_score(%FibaScoresheet.PointScore{
          type: "2PT",
          player_number: 23,
          period: 1,
          is_last_of_period: false
        })
        |> TeamManager.add_score(%FibaScoresheet.PointScore{
          type: "2PT",
          player_number: 23,
          period: 1,
          is_last_of_period: false
        })
        |> TeamManager.add_score(%FibaScoresheet.PointScore{
          type: "2PT",
          player_number: 23,
          period: 1,
          is_last_of_period: false
        })

      fiba_scoresheet =
        fiba_scoresheet
        |> FibaScoresheetManager.update_team("home", updated_team_a)
        |> FibaScoresheetManager.update_team("away", updated_team_b)

      result_scoresheet =
        EndPeriodProcessor.process(event_log, fiba_scoresheet)

      assert result_scoresheet
             |> FibaScoresheetManager.find_team("home")
             |> Map.get(:running_score)
             |> Map.get(10) == %FibaScoresheet.PointScore{
               type: "2PT",
               player_number: 12,
               period: 1,
               is_last_of_period: true
             }

      assert result_scoresheet
             |> FibaScoresheetManager.find_team("away")
             |> Map.get(:running_score)
             |> Map.get(6) == %FibaScoresheet.PointScore{
               type: "2PT",
               player_number: 23,
               period: 1,
               is_last_of_period: true
             }

      assert result_scoresheet.info.ended_periods == [1]
    end

    test "marks both player and coach fouls as last_of_half for both teams when period 2 ends" do
      game_state = basketball_game_state_fixture()

      event =
        GoChampsScoreboard.Events.Definitions.EndPeriodDefinition.create(
          game_state.id,
          0,
          2,
          %{}
        )

      updated_game_state = GoChampsScoreboard.Events.Handler.handle(game_state, event)

      {:ok, event_log} = EventLogs.persist(event, updated_game_state)

      team_a_players = [
        %FibaScoresheet.Player{id: "123", name: "Player 1", number: 12, fouls: []},
        %FibaScoresheet.Player{id: "456", name: "Player 2", number: 15, fouls: []}
      ]

      team_b_players = [
        %FibaScoresheet.Player{id: "789", name: "Player 3", number: 23, fouls: []},
        %FibaScoresheet.Player{id: "101", name: "Player 4", number: 25, fouls: []}
      ]

      fiba_scoresheet =
        fiba_scoresheet_fixture(
          game_id: event_log.game_id,
          team_a_players: team_a_players,
          team_b_players: team_b_players
        )

      updated_team_a =
        fiba_scoresheet
        |> FibaScoresheetManager.find_team("home")
        |> TeamManager.add_player_foul("123", %FibaScoresheet.Foul{
          type: "P",
          period: 1,
          extra_action: nil
        })
        |> TeamManager.add_player_foul("456", %FibaScoresheet.Foul{
          type: "T",
          period: 2,
          extra_action: nil
        })
        |> TeamManager.add_coach_foul("home-coach-id", %FibaScoresheet.Foul{
          type: "T",
          period: 1,
          extra_action: nil
        })

      updated_team_b =
        fiba_scoresheet
        |> FibaScoresheetManager.find_team("away")
        |> TeamManager.add_player_foul("789", %FibaScoresheet.Foul{
          type: "P",
          period: 1,
          extra_action: nil
        })
        |> TeamManager.add_coach_foul("away-assistant-coach-id", %FibaScoresheet.Foul{
          type: "T",
          period: 2,
          extra_action: nil
        })

      fiba_scoresheet =
        fiba_scoresheet
        |> FibaScoresheetManager.update_team("home", updated_team_a)
        |> FibaScoresheetManager.update_team("away", updated_team_b)

      result_scoresheet =
        EndPeriodProcessor.process(event_log, fiba_scoresheet)

      home_team = FibaScoresheetManager.find_team(result_scoresheet, "home")
      home_player_123 = Enum.find(home_team.players, fn p -> p.id == "123" end)
      home_player_456 = Enum.find(home_team.players, fn p -> p.id == "456" end)

      assert Enum.at(home_player_123.fouls, 0).is_last_of_half == true
      assert Enum.at(home_player_456.fouls, 0).is_last_of_half == true
      assert Enum.at(home_team.coach.fouls, 0).is_last_of_half == true

      away_team = FibaScoresheetManager.find_team(result_scoresheet, "away")
      away_player_789 = Enum.find(away_team.players, fn p -> p.id == "789" end)

      assert Enum.at(away_player_789.fouls, 0).is_last_of_half == true
      assert Enum.at(away_team.assistant_coach.fouls, 0).is_last_of_half == true

      assert result_scoresheet.info.ended_periods == [2]
    end

    test "marks both player and coach fouls as last_of_half for both teams when period 4 ends" do
      game_state = basketball_game_state_fixture()

      event =
        GoChampsScoreboard.Events.Definitions.EndPeriodDefinition.create(
          game_state.id,
          0,
          4,
          %{}
        )

      updated_game_state = GoChampsScoreboard.Events.Handler.handle(game_state, event)

      {:ok, event_log} = EventLogs.persist(event, updated_game_state)

      team_a_players = [
        %FibaScoresheet.Player{id: "123", name: "Player 1", number: 12, fouls: []}
      ]

      team_b_players = [
        %FibaScoresheet.Player{id: "789", name: "Player 3", number: 23, fouls: []}
      ]

      fiba_scoresheet =
        fiba_scoresheet_fixture(
          game_id: event_log.game_id,
          team_a_players: team_a_players,
          team_b_players: team_b_players
        )

      updated_team_a =
        fiba_scoresheet
        |> FibaScoresheetManager.find_team("home")
        |> TeamManager.add_player_foul("123", %FibaScoresheet.Foul{
          type: "P",
          period: 3,
          extra_action: nil
        })
        |> TeamManager.add_coach_foul("home-coach-id", %FibaScoresheet.Foul{
          type: "T",
          period: 4,
          extra_action: nil
        })

      updated_team_b =
        fiba_scoresheet
        |> FibaScoresheetManager.find_team("away")
        |> TeamManager.add_player_foul("789", %FibaScoresheet.Foul{
          type: "P",
          period: 1,
          extra_action: nil
        })
        |> TeamManager.add_coach_foul("away-coach-id", %FibaScoresheet.Foul{
          type: "T",
          period: 2,
          extra_action: nil
        })

      fiba_scoresheet =
        fiba_scoresheet
        |> FibaScoresheetManager.update_team("home", updated_team_a)
        |> FibaScoresheetManager.update_team("away", updated_team_b)

      result_scoresheet =
        EndPeriodProcessor.process(event_log, fiba_scoresheet)

      home_team = FibaScoresheetManager.find_team(result_scoresheet, "home")
      home_player_123 = Enum.find(home_team.players, fn p -> p.id == "123" end)

      assert Enum.at(home_player_123.fouls, 0).is_last_of_half == true
      assert Enum.at(home_team.coach.fouls, 0).is_last_of_half == true

      away_team = FibaScoresheetManager.find_team(result_scoresheet, "away")
      away_player_789 = Enum.find(away_team.players, fn p -> p.id == "789" end)

      assert Enum.at(away_player_789.fouls, 0).is_last_of_half == true
      assert Enum.at(away_team.coach.fouls, 0).is_last_of_half == true

      assert result_scoresheet.info.ended_periods == [4]
    end

    test "handles teams with no player or coach fouls gracefully" do
      game_state = basketball_game_state_fixture()

      event =
        GoChampsScoreboard.Events.Definitions.EndPeriodDefinition.create(
          game_state.id,
          0,
          2,
          %{}
        )

      updated_game_state = GoChampsScoreboard.Events.Handler.handle(game_state, event)

      {:ok, event_log} = EventLogs.persist(event, updated_game_state)

      team_a_players = [
        %FibaScoresheet.Player{id: "123", name: "Player 1", number: 12, fouls: []}
      ]

      team_b_players = [
        %FibaScoresheet.Player{id: "456", name: "Player 2", number: 23, fouls: []}
      ]

      fiba_scoresheet =
        fiba_scoresheet_fixture(
          game_id: event_log.game_id,
          team_a_players: team_a_players,
          team_b_players: team_b_players
        )

      result_scoresheet =
        EndPeriodProcessor.process(event_log, fiba_scoresheet)

      home_team = FibaScoresheetManager.find_team(result_scoresheet, "home")
      away_team = FibaScoresheetManager.find_team(result_scoresheet, "away")

      home_player = Enum.find(home_team.players, fn p -> p.id == "123" end)
      away_player = Enum.find(away_team.players, fn p -> p.id == "456" end)

      assert home_player.fouls == []
      assert away_player.fouls == []
      assert home_team.coach.fouls == []
      assert home_team.assistant_coach.fouls == []
      assert away_team.coach.fouls == []
      assert away_team.assistant_coach.fouls == []

      assert result_scoresheet.info.ended_periods == [2]
    end

    test "does not duplicate a period already marked as ended" do
      game_state = basketball_game_state_fixture()

      event =
        GoChampsScoreboard.Events.Definitions.EndPeriodDefinition.create(
          game_state.id,
          0,
          1,
          %{}
        )

      updated_game_state = GoChampsScoreboard.Events.Handler.handle(game_state, event)

      {:ok, event_log} = EventLogs.persist(event, updated_game_state)

      fiba_scoresheet = fiba_scoresheet_fixture(game_id: event_log.game_id)

      fiba_scoresheet =
        FibaScoresheetManager.update_info(fiba_scoresheet, %{
          fiba_scoresheet.info
          | ended_periods: [1]
        })

      result_scoresheet = EndPeriodProcessor.process(event_log, fiba_scoresheet)

      assert result_scoresheet.info.ended_periods == [1]
    end
  end
end
