defmodule GoChampsScoreboard.Sports.Basketball.Reports.FibaScoresheet.FibaScoresheetManagerTest do
  use ExUnit.Case
  use GoChampsScoreboard.DataCase

  alias GoChampsScoreboard.Sports.Basketball.Reports.FibaScoresheet.FibaScoresheetManager
  alias GoChampsScoreboard.Games.EventLogs
  alias GoChampsScoreboard.Sports.Basketball.Reports.FibaScoresheet
  import GoChampsScoreboard.GameStateFixtures

  describe "bootstrap/1" do
    test "returns a FibaScoresheet struct with game_id" do
      game_state = basketball_game_state_fixture()

      {:ok, datetime, _} =
        "2023-10-01T12:00:00Z"
        |> DateTime.from_iso8601()

      # 1 hour later
      actual_start_datetime = DateTime.add(datetime, 60 * 60)
      # 1 hour after that
      actual_end_datetime = DateTime.add(actual_start_datetime, 60 * 60)

      event =
        GoChampsScoreboard.Events.Definitions.StartGameLiveModeDefinition.create(
          game_state.id,
          game_state.clock_state.time,
          game_state.clock_state.period,
          %{}
        )

      updated_game_state = GoChampsScoreboard.Events.Handler.handle(game_state, event)

      {:ok, event_log} = EventLogs.persist(event, updated_game_state)

      expected = %FibaScoresheet{
        game_id: event_log.game_id,
        info: %FibaScoresheet.Info{
          number: "ABC123",
          location: "Game Location",
          city: "Game City",
          datetime: datetime,
          tournament_name: "Tournament Name",
          tournament_slug: "",
          tournament_logo_url: "/media/tournament_logo.png",
          organization_name: "Organization Name",
          organization_slug: "",
          organization_logo_url: "/media/logo.png",
          actual_start_datetime: actual_start_datetime,
          actual_end_datetime: actual_end_datetime,
          initial_period_time: game_state.clock_state.initial_period_time,
          game_report: "This is a game report.",
          web_url: "http://example.com/game_report",
          sponsors: [
            %{
              name: "Sponsor A",
              link: "http://sponsora.com",
              logo_url: "/sponsor_a.png"
            },
            %{
              name: "Sponsor B",
              link: "http://sponsorb.com",
              logo_url: "/sponsor_b.png"
            }
          ],
          ended_periods: []
        },
        team_a: %FibaScoresheet.Team{
          name: "Some home team",
          coach: %FibaScoresheet.Coach{id: "coach-id", name: "First coach", fouls: []},
          assistant_coach: %FibaScoresheet.Coach{
            id: "assistant-coach-id",
            name: "Assistant coach",
            fouls: []
          },
          players: [
            %FibaScoresheet.Player{
              id: "123",
              name: "Player 1",
              number: 12,
              fouls: [],
              is_captain: false,
              has_played: nil,
              has_started: nil
            },
            %FibaScoresheet.Player{
              id: "124",
              name: "Player 2",
              number: 23,
              fouls: [],
              is_captain: false,
              has_played: nil,
              has_started: nil
            }
          ],
          all_fouls: [],
          timeouts: [],
          running_score: %{},
          head_coach_challenges: [],
          score: 0,
          has_walkover: false,
          points_by_period: %{},
          points_summary: %{}
        },
        team_b: %FibaScoresheet.Team{
          name: "Some away team",
          coach: %FibaScoresheet.Coach{id: "away-coach-id", name: "Away coach", fouls: []},
          assistant_coach: %FibaScoresheet.Coach{
            id: "away-assistant-coach-id",
            name: "Away assistant coach",
            fouls: []
          },
          players: [
            %FibaScoresheet.Player{
              id: "456",
              name: "Player 2",
              number: 23,
              fouls: [],
              is_captain: false
            }
          ],
          all_fouls: [],
          timeouts: [],
          running_score: %{},
          head_coach_challenges: [],
          score: 0,
          has_walkover: false,
          points_by_period: %{},
          points_summary: %{}
        },
        scorer: %FibaScoresheet.Official{
          id: "scorer-official-id",
          name: "John Scorer",
          federation: "FIBA"
        },
        assistant_scorer: %FibaScoresheet.Official{
          id: "assistant-scorer-official-id",
          name: "Jane Assistant Scorer",
          federation: "FIBA"
        },
        timekeeper: %FibaScoresheet.Official{
          id: "timekeeper-official-id",
          name: "Mike Timekeeper",
          federation: "NBA"
        },
        shot_clock_operator: %FibaScoresheet.Official{
          id: "shot-clock-operator-official-id",
          name: "Sarah Shot Clock",
          federation: "NCAA"
        },
        crew_chief: %FibaScoresheet.Official{
          id: "crew-chief-official-id",
          name: "Robert Crew Chief",
          federation: "NBA"
        },
        umpire_1: %FibaScoresheet.Official{
          id: "umpire-1-official-id",
          name: "David Umpire One",
          federation: "FIBA"
        },
        umpire_2: %FibaScoresheet.Official{
          id: "umpire-2-official-id",
          name: "Lisa Umpire Two",
          federation: "FIBA"
        },
        protest: %FibaScoresheet.Protest{
          state: :protest_filed,
          player_name: "Player 1"
        }
      }

      assert expected == FibaScoresheetManager.bootstrap(event_log)
    end
  end

  describe "find_team/2" do
    test "returns the team with a given type" do
      team_a = %FibaScoresheet.Team{name: "Team A", players: []}
      team_b = %FibaScoresheet.Team{name: "Team B", players: []}

      fiba_scoresheet = %FibaScoresheet{
        team_a: team_a,
        team_b: team_b
      }

      assert FibaScoresheetManager.find_team(fiba_scoresheet, "home") == team_a
      assert FibaScoresheetManager.find_team(fiba_scoresheet, "away") == team_b
    end
  end

  describe "update_team/3" do
    test "updates the team with the given type" do
      team_a = %FibaScoresheet.Team{name: "Team A", players: []}
      team_b = %FibaScoresheet.Team{name: "Team B", players: []}

      fiba_scoresheet = %FibaScoresheet{
        team_a: team_a,
        team_b: team_b
      }

      updated_team = %FibaScoresheet.Team{name: "Updated Team A", players: []}

      updated_fiba_scoresheet =
        FibaScoresheetManager.update_team(fiba_scoresheet, "home", updated_team)

      assert updated_fiba_scoresheet.team_a.name == "Updated Team A"
      assert updated_fiba_scoresheet.team_b.name == "Team B"
    end
  end
end
