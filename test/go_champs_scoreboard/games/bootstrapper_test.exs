defmodule GoChampsScoreboard.Games.BootstrapperTest do
  use ExUnit.Case
  alias GoChampsScoreboard.Games.Bootstrapper

  import Mox

  describe "bootstrap" do
    test "bootstraps with random game-id" do
      game = Bootstrapper.bootstrap()
      assert String.length(game.id) > 0
    end

    test "bootstraps with home team and away team" do
      game = Bootstrapper.bootstrap()
      assert game.away_team.name == "Away team"
      assert game.away_team.players == []
      assert game.away_team.total_player_stats == %{}
      assert game.home_team.name == "Home team"
      assert game.home_team.players == []
      assert game.home_team.total_player_stats == %{}
    end
  end

  describe "bootstrap_from_api" do
    @http_client GoChampsScoreboard.HTTPClientMock
    @response_body %{
      "data" => %{
        "meta" => %{"permissions" => ["game:operate"]},
        "id" => "game-id",
        "away_team" => %{
          "name" => "Team A",
          "tri_code" => "ABC",
          "logo_url" => "https://example.com/logo.png",
          "players" => [
            %{
              "id" => "player-1",
              "name" => "Player 1",
              "shirt_name" => "P 1",
              "shirt_number" => "1",
              "license_number" => "L1"
            },
            %{
              "id" => "player-2",
              "name" => "Player 2",
              "shirt_number" => "2",
              "license_number" => "L2"
            },
            %{
              "id" => "player-3",
              "name" => "Player 3",
              "shirt_name" => "P 3"
            },
            %{
              "id" => "player-4",
              "name" => "Player 4"
            },
            %{
              "id" => "player-5",
              "name" => "Player 5"
            },
            %{
              "id" => "player-6",
              "name" => "Player 6"
            }
          ]
        },
        "home_team" => %{
          "name" => "Team B",
          "players" => [
            %{
              "id" => "player-7",
              "name" => "Player 7",
              "shirt_name" => "P 7",
              "shirt_number" => "7"
            },
            %{
              "id" => "player-8",
              "name" => "Player 8",
              "shirt_number" => "8"
            },
            %{
              "id" => "player-9",
              "name" => "Player 9",
              "shirt_name" => "P 9"
            },
            %{
              "id" => "player-10",
              "name" => "Player 10"
            },
            %{
              "id" => "player-11",
              "name" => "Player 11"
            },
            %{
              "id" => "player-12",
              "name" => "Player 12"
            }
          ]
        },
        "live_state" => "ended"
      }
    }
    @response_body_with_coaches %{
      "data" => %{
        "meta" => %{"permissions" => ["game:operate"]},
        "id" => "game-id",
        "away_team" => %{
          "name" => "Team A",
          "tri_code" => "ABC",
          "logo_url" => "https://example.com/logo.png",
          "players" => [
            %{
              "id" => "player-1",
              "name" => "Player 1",
              "shirt_name" => "P 1",
              "shirt_number" => "1"
            }
          ],
          "coaches" => [
            %{
              "id" => "coach-1",
              "name" => "Coach 1",
              "type" => "head_coach",
              "state" => "available"
            },
            %{
              "id" => "coach-2",
              "name" => "Coach 2",
              "type" => "assistant_coach"
            }
          ]
        },
        "home_team" => %{
          "name" => "Team B",
          "players" => [
            %{
              "id" => "player-2",
              "name" => "Player 2",
              "shirt_name" => "P 2",
              "shirt_number" => "2"
            }
          ],
          "coaches" => [
            %{
              "id" => "coach-3",
              "name" => "Coach 3",
              "type" => "head_coach",
              "state" => "not_available"
            },
            %{
              "id" => "coach-4",
              "name" => "Coach 4",
              "type" => "assistant_coach",
              "state" => "available"
            }
          ]
        },
        "live_state" => "ended"
      }
    }
    @response_body_with_info %{
      "data" => %{
        "meta" => %{"permissions" => ["game:operate"]},
        "id" => "game-id",
        "away_team" => %{
          "name" => "Team A",
          "tri_code" => "ABC",
          "logo_url" => "https://example.com/logo.png",
          "players" => [
            %{
              "id" => "player-1",
              "name" => "Player 1",
              "shirt_name" => "P 1",
              "shirt_number" => "1"
            }
          ]
        },
        "home_team" => %{
          "name" => "Team B",
          "players" => [
            %{
              "id" => "player-2",
              "name" => "Player 2",
              "shirt_name" => "P 2",
              "shirt_number" => "2"
            }
          ]
        },
        "datetime" => "2023-10-01T12:00:00Z",
        "location" => "Stadium A",
        "phase" => %{
          "tournament" => %{
            "id" => "tournament-id",
            "name" => "Tournament Name",
            "slug" => "tournament-slug"
          }
        },
        "web_url" => "http://example.com/games/game-id"
      }
    }

    @response_body_with_organization %{
      "data" => %{
        "meta" => %{"permissions" => ["game:operate"]},
        "id" => "game-id",
        "away_team" => %{
          "name" => "Team A",
          "tri_code" => "ABC",
          "logo_url" => "https://example.com/logo.png",
          "players" => [
            %{
              "id" => "player-1",
              "name" => "Player 1",
              "shirt_name" => "P 1",
              "shirt_number" => "1"
            }
          ]
        },
        "home_team" => %{
          "name" => "Team B",
          "players" => [
            %{
              "id" => "player-2",
              "name" => "Player 2",
              "shirt_name" => "P 2",
              "shirt_number" => "2"
            }
          ]
        },
        "datetime" => "2023-10-01T12:00:00Z",
        "location" => "Stadium A",
        "phase" => %{
          "tournament" => %{
            "id" => "tournament-id",
            "name" => "Tournament Name",
            "slug" => "tournament-slug",
            "organization" => %{
              "id" => "organization-id",
              "name" => "Organization Name",
              "slug" => "organization-slug",
              "logo_url" => "http://host/logo.png"
            }
          }
        }
      }
    }

    @response_body_with_primary_colors %{
      "data" => %{
        "meta" => %{"permissions" => ["game:operate"]},
        "id" => "game-id",
        "away_team" => %{
          "name" => "Team A",
          "tri_code" => "ABC",
          "logo_url" => "https://example.com/logo.png",
          "primary_color" => "#FF0000",
          "players" => [
            %{
              "id" => "player-1",
              "name" => "Player 1",
              "shirt_name" => "P 1",
              "shirt_number" => "1"
            }
          ]
        },
        "home_team" => %{
          "name" => "Team B",
          "primary_color" => "#0000FF",
          "players" => [
            %{
              "id" => "player-2",
              "name" => "Player 2",
              "shirt_name" => "P 2",
              "shirt_number" => "2"
            }
          ]
        }
      }
    }

    @response_body_with_officials %{
      "data" => %{
        "meta" => %{"permissions" => ["game:operate"]},
        "id" => "game-id",
        "away_team" => %{
          "name" => "Team A",
          "players" => []
        },
        "home_team" => %{
          "name" => "Team B",
          "players" => []
        },
        "officials" => [
          %{
            "id" => "embedded-official-1",
            "official_id" => "official-uuid-1",
            "role" => "crew_chief",
            "official" => %{
              "id" => "official-uuid-1",
              "name" => "John Chief",
              "license_number" => "REF001",
              "federation" => "FIBA",
              "username" => "johnchief",
              "tournament_id" => "tournament-uuid"
            }
          },
          %{
            "id" => "embedded-official-2",
            "official_id" => "official-uuid-2",
            "role" => "scorer",
            "official" => %{
              "id" => "official-uuid-2",
              "name" => "Jane Scorer",
              "license_number" => "SCR001",
              "username" => "janescorer",
              "tournament_id" => "tournament-uuid"
            }
          }
        ],
        "live_state" => "not_started"
      }
    }

    @response_body_with_referee_role %{
      "data" => %{
        "meta" => %{"permissions" => ["game:operate"]},
        "id" => "game-id",
        "away_team" => %{
          "name" => "Team A",
          "players" => []
        },
        "home_team" => %{
          "name" => "Team B",
          "players" => []
        },
        "officials" => [
          %{
            "id" => "embedded-official-1",
            "official_id" => "official-uuid-1",
            "role" => "referee",
            "official" => %{
              "id" => "official-uuid-1",
              "name" => "John Referee",
              "license_number" => "REF001",
              "username" => "johnref",
              "tournament_id" => "tournament-uuid"
            }
          }
        ],
        "live_state" => "not_started"
      }
    }

    @response_body_with_invalid_officials %{
      "data" => %{
        "meta" => %{"permissions" => ["game:operate"]},
        "id" => "game-id",
        "away_team" => %{
          "name" => "Team A",
          "players" => []
        },
        "home_team" => %{
          "name" => "Team B",
          "players" => []
        },
        "officials" => [
          %{
            "id" => "embedded-official-1",
            "official_id" => "official-uuid-1",
            "role" => "invalid_role",
            "official" => %{
              "id" => "official-uuid-1",
              "name" => "Invalid Official",
              "license_number" => "INV001"
            }
          },
          %{
            "id" => "embedded-official-2",
            "official_id" => "official-uuid-2",
            "role" => "scorer",
            "official" => %{
              "id" => "official-uuid-2",
              "name" => "Valid Scorer",
              "license_number" => "SCR001"
            }
          }
        ],
        "live_state" => "not_started"
      }
    }

    @response_setting_full_body %{
      "data" => %{
        "view" => "basketball-basic-stats",
        "available_views" => [
          "basketball-basic-stats",
          "basketball-medium-stats-plus-scoresheet-scoresheet-only"
        ],
        "initial_extra_period_time" => 200,
        "initial_period_time" => 500
      }
    }

    @response_setting_empty_body %{
      "data" => %{}
    }

    @response_body_with_tournament_logo_and_sponsors %{
      "data" => %{
        "meta" => %{"permissions" => ["game:operate"]},
        "id" => "game-id",
        "away_team" => %{
          "name" => "Team A",
          "players" => []
        },
        "home_team" => %{
          "name" => "Team B",
          "players" => []
        },
        "phase" => %{
          "tournament" => %{
            "id" => "tournament-id",
            "name" => "Tournament Name",
            "slug" => "tournament-slug",
            "logo_url" => "http://example.com/tournament_logo.png",
            "sponsors" => [
              %{
                "name" => "Sponsor A",
                "link" => "http://sponsora.com",
                "logo_url" => "http://example.com/sponsor_a.png"
              },
              %{
                "name" => "Sponsor B",
                "link" => "http://sponsorb.com",
                "logo_url" => "http://example.com/sponsor_b.png"
              }
            ]
          }
        },
        "live_state" => "not_started"
      }
    }

    @response_body_with_number %{
      "data" => %{
        "meta" => %{"permissions" => ["game:operate"]},
        "id" => "game-id",
        "number" => "12345",
        "away_team" => %{
          "name" => "Team A",
          "players" => []
        },
        "home_team" => %{
          "name" => "Team B",
          "players" => []
        },
        "live_state" => "not_started"
      }
    }

    @response_body_with_empty_number %{
      "data" => %{
        "meta" => %{"permissions" => ["game:operate"]},
        "id" => "game-id",
        "number" => "",
        "away_team" => %{
          "name" => "Team A",
          "players" => []
        },
        "home_team" => %{
          "name" => "Team B",
          "players" => []
        },
        "live_state" => "not_started"
      }
    }

    @response_body_with_null_number %{
      "data" => %{
        "meta" => %{"permissions" => ["game:operate"]},
        "id" => "game-id",
        "number" => nil,
        "away_team" => %{
          "name" => "Team A",
          "players" => []
        },
        "home_team" => %{
          "name" => "Team B",
          "players" => []
        },
        "live_state" => "not_started"
      }
    }

    test "maps game id" do
      expect(@http_client, :get, fn url, headers, _opts ->
        assert url =~ "game-id"
        assert headers == [{"Authorization", "Bearer token"}]

        {:ok, %HTTPoison.Response{body: @response_body |> Poison.encode!(), status_code: 200}}
      end)

      expect(@http_client, :get, fn url, _headers, _opts ->
        assert url =~ "game-id/scoreboard-setting"

        {:ok, %HTTPoison.Response{body: %{"data" => nil} |> Poison.encode!(), status_code: 200}}
      end)

      game =
        Bootstrapper.bootstrap_from_go_champs(
          GoChampsScoreboard.Games.Bootstrapper.bootstrap(),
          "game-id",
          "token"
        )

      [player_1, player_2, player_3, player_4, player_5, player_6] = game.away_team.players
      assert game.id == "game-id"
      assert game.away_team.name == "Team A"
      assert player_1.id == "player-1"
      assert player_1.name == "P 1"
      assert player_1.number == "1"
      assert player_1.license_number == "L1"
      assert player_1.state == :available
      assert player_2.id == "player-2"
      assert player_2.name == "Player 2"
      assert player_2.number == "2"
      assert player_2.license_number == "L2"
      assert player_2.state == :available
      assert player_3.id == "player-3"
      assert player_3.name == "P 3"
      assert player_3.number == nil
      assert player_3.state == :available
      assert player_4.id == "player-4"
      assert player_4.name == "Player 4"
      assert player_4.number == nil
      assert player_4.state == :available
      assert player_5.id == "player-5"
      assert player_5.name == "Player 5"
      assert player_5.number == nil
      assert player_5.state == :available
      assert player_6.id == "player-6"
      assert player_6.name == "Player 6"
      assert player_6.number == nil
      assert player_6.state == :available
      assert game.away_team.total_player_stats == %{}
      assert game.away_team.tri_code == "ABC"
      assert game.away_team.logo_url == "https://example.com/logo.png"

      [player_7, player_8, player_9, player_10, player_11, player_12] = game.home_team.players
      assert game.home_team.name == "Team B"
      assert player_7.id == "player-7"
      assert player_7.name == "P 7"
      assert player_7.number == "7"
      assert player_7.state == :available
      assert player_8.id == "player-8"
      assert player_8.name == "Player 8"
      assert player_8.number == "8"
      assert player_8.state == :available
      assert player_9.id == "player-9"
      assert player_9.name == "P 9"
      assert player_9.number == nil
      assert player_9.state == :available
      assert player_10.id == "player-10"
      assert player_10.name == "Player 10"
      assert player_10.number == nil
      assert player_10.state == :available
      assert player_11.id == "player-11"
      assert player_11.name == "Player 11"
      assert player_11.number == nil
      assert player_11.state == :available
      assert player_12.id == "player-12"
      assert player_12.name == "Player 12"
      assert player_12.number == nil
      assert player_12.state == :available
      assert game.home_team.total_player_stats == %{}
      assert game.home_team.tri_code == ""
      assert game.home_team.logo_url == ""

      assert game.live_state.state == :ended
      assert game.sport_id == "basketball"
      assert game.view_settings_state.view == "basketball-medium-stats"
    end

    test "maps game and view settings" do
      expect(@http_client, :get, fn url, headers, _opts ->
        assert url =~ "game-id"
        assert headers == [{"Authorization", "Bearer token"}]

        {:ok, %HTTPoison.Response{body: @response_body |> Poison.encode!(), status_code: 200}}
      end)

      expect(@http_client, :get, fn url, _headers, _opts ->
        assert url =~ "game-id/scoreboard-setting"

        {:ok,
         %HTTPoison.Response{
           body: @response_setting_full_body |> Poison.encode!(),
           status_code: 200
         }}
      end)

      game =
        Bootstrapper.bootstrap_from_go_champs(
          GoChampsScoreboard.Games.Bootstrapper.bootstrap(),
          "game-id",
          "token"
        )

      assert game.sport_id == "basketball"
      assert game.view_settings_state.view == "basketball-basic-stats"

      assert game.view_settings_state.available_views == [
               "basketball-basic-stats",
               "basketball-medium-stats-plus-scoresheet-scoresheet-only"
             ]

      assert game.clock_state.initial_period_time == 500
      assert game.clock_state.initial_extra_period_time == 200
    end

    test "maps default values when view settings are empty" do
      expect(@http_client, :get, fn url, headers, _opts ->
        assert url =~ "game-id"
        assert headers == [{"Authorization", "Bearer token"}]

        {:ok, %HTTPoison.Response{body: @response_body |> Poison.encode!(), status_code: 200}}
      end)

      expect(@http_client, :get, fn url, _headers, _opts ->
        assert url =~ "game-id/scoreboard-setting"

        {:ok,
         %HTTPoison.Response{
           body: @response_setting_empty_body |> Poison.encode!(),
           status_code: 200
         }}
      end)

      game =
        Bootstrapper.bootstrap_from_go_champs(
          GoChampsScoreboard.Games.Bootstrapper.bootstrap(),
          "game-id",
          "token"
        )

      assert game.sport_id == "basketball"
      assert game.view_settings_state.view == "basketball-medium-stats"
      assert game.view_settings_state.available_views == []
      assert game.clock_state.initial_period_time == 600
      assert game.clock_state.initial_extra_period_time == 300
    end

    test "maps game and team coaches" do
      expect(@http_client, :get, fn url, headers, _opts ->
        assert url =~ "game-id"
        assert headers == [{"Authorization", "Bearer token"}]

        {:ok,
         %HTTPoison.Response{
           body: @response_body_with_coaches |> Poison.encode!(),
           status_code: 200
         }}
      end)

      expect(@http_client, :get, fn url, _headers, _opts ->
        assert url =~ "game-id/scoreboard-setting"

        {:ok, %HTTPoison.Response{body: %{"data" => nil} |> Poison.encode!(), status_code: 200}}
      end)

      game =
        Bootstrapper.bootstrap_from_go_champs(
          GoChampsScoreboard.Games.Bootstrapper.bootstrap(),
          "game-id",
          "token"
        )

      [coach_1, coach_2] = game.away_team.coaches
      assert coach_1.id == "coach-1"
      assert coach_1.name == "Coach 1"
      assert coach_1.type == :head_coach
      assert coach_1.state == :available
      assert coach_2.id == "coach-2"
      assert coach_2.name == "Coach 2"
      assert coach_2.type == :assistant_coach
      assert coach_2.state == :available

      [coach_3, coach_4] = game.home_team.coaches
      assert coach_3.id == "coach-3"
      assert coach_3.name == "Coach 3"
      assert coach_3.type == :head_coach
      assert coach_3.state == :not_available
      assert coach_4.id == "coach-4"
      assert coach_4.name == "Coach 4"
      assert coach_4.type == :assistant_coach
      assert coach_4.state == :available
    end

    test "maps game and info" do
      expect(@http_client, :get, fn url, headers, _opts ->
        assert url =~ "game-id"
        assert headers == [{"Authorization", "Bearer token"}]

        {:ok,
         %HTTPoison.Response{
           body: @response_body_with_info |> Poison.encode!(),
           status_code: 200
         }}
      end)

      expect(@http_client, :get, fn url, _headers, _opts ->
        assert url =~ "game-id/scoreboard-setting"

        {:ok,
         %HTTPoison.Response{
           body: @response_setting_full_body |> Poison.encode!(),
           status_code: 200
         }}
      end)

      game =
        Bootstrapper.bootstrap_from_go_champs(
          GoChampsScoreboard.Games.Bootstrapper.bootstrap(),
          "game-id",
          "token"
        )

      {:ok, expected_datetime, _} = DateTime.from_iso8601("2023-10-01T12:00:00Z")

      assert game.info.datetime == expected_datetime
      assert game.info.tournament_id == "tournament-id"
      assert game.info.tournament_name == "Tournament Name"
      assert game.info.tournament_slug == "tournament-slug"
      assert game.info.location == "Stadium A"
      assert game.info.number == "game-id"
      assert game.info.web_url == "http://example.com/games/game-id"
    end

    test "maps game and organization info" do
      expect(@http_client, :get, fn url, headers, _opts ->
        assert url =~ "game-id"
        assert headers == [{"Authorization", "Bearer token"}]

        {:ok,
         %HTTPoison.Response{
           body: @response_body_with_organization |> Poison.encode!(),
           status_code: 200
         }}
      end)

      expect(@http_client, :get, fn url, _headers, _opts ->
        assert url =~ "game-id/scoreboard-setting"

        {:ok,
         %HTTPoison.Response{
           body: @response_setting_full_body |> Poison.encode!(),
           status_code: 200
         }}
      end)

      game =
        Bootstrapper.bootstrap_from_go_champs(
          GoChampsScoreboard.Games.Bootstrapper.bootstrap(),
          "game-id",
          "token"
        )

      {:ok, expected_datetime, _} = DateTime.from_iso8601("2023-10-01T12:00:00Z")

      assert game.info.datetime == expected_datetime
      assert game.info.tournament_id == "tournament-id"
      assert game.info.tournament_name == "Tournament Name"
      assert game.info.tournament_slug == "tournament-slug"
      assert game.info.organization_name == "Organization Name"
      assert game.info.organization_slug == "organization-slug"
      assert game.info.organization_logo_url == "http://host/logo.png"
      assert game.info.location == "Stadium A"
      assert game.info.number == "game-id"
    end

    test "maps default sport officials when none from API" do
      expect(@http_client, :get, fn url, headers, _opts ->
        assert url =~ "game-id"
        assert headers == [{"Authorization", "Bearer token"}]

        {:ok, %HTTPoison.Response{body: @response_body |> Poison.encode!(), status_code: 200}}
      end)

      expect(@http_client, :get, fn url, _headers, _opts ->
        assert url =~ "game-id/scoreboard-setting"

        {:ok, %HTTPoison.Response{body: %{"data" => nil} |> Poison.encode!(), status_code: 200}}
      end)

      game =
        Bootstrapper.bootstrap_from_go_champs(
          GoChampsScoreboard.Games.Bootstrapper.bootstrap(),
          "game-id",
          "token"
        )

      assert length(game.officials) == 7
      types = Enum.map(game.officials, fn official -> official.type end)

      assert :crew_chief in types
      assert :umpire_1 in types
      assert :umpire_2 in types
      assert :scorer in types
      assert :assistant_scorer in types
      assert :timekeeper in types
      assert :shot_clock_operator in types
    end

    test "maps team primary colors when provided by API" do
      expect(@http_client, :get, fn url, headers, _opts ->
        assert url =~ "game-id"
        assert headers == [{"Authorization", "Bearer token"}]

        {:ok,
         %HTTPoison.Response{
           body: @response_body_with_primary_colors |> Poison.encode!(),
           status_code: 200
         }}
      end)

      expect(@http_client, :get, fn url, _headers, _opts ->
        assert url =~ "game-id/scoreboard-setting"

        {:ok, %HTTPoison.Response{body: %{"data" => nil} |> Poison.encode!(), status_code: 200}}
      end)

      game =
        Bootstrapper.bootstrap_from_go_champs(
          GoChampsScoreboard.Games.Bootstrapper.bootstrap(),
          "game-id",
          "token"
        )

      assert game.away_team.primary_color == "#FF0000"
      assert game.home_team.primary_color == "#0000FF"
    end

    test "defaults primary color to nil when not provided by API" do
      expect(@http_client, :get, fn url, headers, _opts ->
        assert url =~ "game-id"
        assert headers == [{"Authorization", "Bearer token"}]

        {:ok, %HTTPoison.Response{body: @response_body |> Poison.encode!(), status_code: 200}}
      end)

      expect(@http_client, :get, fn url, _headers, _opts ->
        assert url =~ "game-id/scoreboard-setting"

        {:ok, %HTTPoison.Response{body: %{"data" => nil} |> Poison.encode!(), status_code: 200}}
      end)

      game =
        Bootstrapper.bootstrap_from_go_champs(
          GoChampsScoreboard.Games.Bootstrapper.bootstrap(),
          "game-id",
          "token"
        )

      assert game.away_team.primary_color == nil
      assert game.home_team.primary_color == nil
    end

    test "maps API officials when provided" do
      expect(@http_client, :get, fn url, headers, _opts ->
        assert url =~ "game-id"
        assert headers == [{"Authorization", "Bearer token"}]

        {:ok,
         %HTTPoison.Response{
           body: @response_body_with_officials |> Poison.encode!(),
           status_code: 200
         }}
      end)

      expect(@http_client, :get, fn url, _headers, _opts ->
        assert url =~ "game-id/scoreboard-setting"

        {:ok, %HTTPoison.Response{body: %{"data" => nil} |> Poison.encode!(), status_code: 200}}
      end)

      game =
        Bootstrapper.bootstrap_from_go_champs(
          GoChampsScoreboard.Games.Bootstrapper.bootstrap(),
          "game-id",
          "token"
        )

      assert length(game.officials) == 7

      # Find the specific officials that were replaced
      crew_chief = Enum.find(game.officials, &(&1.type == :crew_chief))
      scorer = Enum.find(game.officials, &(&1.type == :scorer))

      # Assert API officials replaced defaults
      assert crew_chief.id == "official-uuid-1"
      assert crew_chief.name == "John Chief"
      assert crew_chief.license_number == "REF001"

      assert scorer.id == "official-uuid-2"
      assert scorer.name == "Jane Scorer"
      assert scorer.license_number == "SCR001"

      # Assert other officials remain as defaults (empty names but have UUIDs)
      other_officials = Enum.filter(game.officials, &(&1.type not in [:crew_chief, :scorer]))

      Enum.each(other_officials, fn official ->
        # Default officials have UUID ids
        assert String.length(official.id) > 0
        assert official.name == ""
      end)
    end

    test "maps referee role to crew_chief type" do
      expect(@http_client, :get, fn url, headers, _opts ->
        assert url =~ "game-id"
        assert headers == [{"Authorization", "Bearer token"}]

        {:ok,
         %HTTPoison.Response{
           body: @response_body_with_referee_role |> Poison.encode!(),
           status_code: 200
         }}
      end)

      expect(@http_client, :get, fn url, _headers, _opts ->
        assert url =~ "game-id/scoreboard-setting"

        {:ok, %HTTPoison.Response{body: %{"data" => nil} |> Poison.encode!(), status_code: 200}}
      end)

      game =
        Bootstrapper.bootstrap_from_go_champs(
          GoChampsScoreboard.Games.Bootstrapper.bootstrap(),
          "game-id",
          "token"
        )

      crew_chief = Enum.find(game.officials, &(&1.type == :crew_chief))
      assert crew_chief.id == "official-uuid-1"
      assert crew_chief.name == "John Referee"
      assert crew_chief.license_number == "REF001"
    end

    test "handles invalid official roles gracefully" do
      expect(@http_client, :get, fn url, headers, _opts ->
        assert url =~ "game-id"
        assert headers == [{"Authorization", "Bearer token"}]

        {:ok,
         %HTTPoison.Response{
           body: @response_body_with_invalid_officials |> Poison.encode!(),
           status_code: 200
         }}
      end)

      expect(@http_client, :get, fn url, _headers, _opts ->
        assert url =~ "game-id/scoreboard-setting"

        {:ok, %HTTPoison.Response{body: %{"data" => nil} |> Poison.encode!(), status_code: 200}}
      end)

      import ExUnit.CaptureLog

      log =
        capture_log(fn ->
          game =
            Bootstrapper.bootstrap_from_go_champs(
              GoChampsScoreboard.Games.Bootstrapper.bootstrap(),
              "game-id",
              "token"
            )

          # Should still have all 7 default officials
          assert length(game.officials) == 7

          # Valid scorer should be mapped
          scorer = Enum.find(game.officials, &(&1.type == :scorer))
          assert scorer.id == "official-uuid-2"
          assert scorer.name == "Valid Scorer"

          # Invalid official should be ignored, default crew_chief remains
          crew_chief = Enum.find(game.officials, &(&1.type == :crew_chief))
          # Default has UUID
          assert String.length(crew_chief.id) > 0
          assert crew_chief.name == ""
        end)

      # Verify warning was logged
      assert log =~ "Invalid official role received from API: invalid_role"
    end

    test "maps tournament logo and sponsors" do
      expect(@http_client, :get, fn url, headers, _opts ->
        assert url =~ "game-id"
        assert headers == [{"Authorization", "Bearer token"}]

        {:ok,
         %HTTPoison.Response{
           body: @response_body_with_tournament_logo_and_sponsors |> Poison.encode!(),
           status_code: 200
         }}
      end)

      expect(@http_client, :get, fn url, _headers, _opts ->
        assert url =~ "game-id/scoreboard-setting"

        {:ok, %HTTPoison.Response{body: %{"data" => nil} |> Poison.encode!(), status_code: 200}}
      end)

      game =
        Bootstrapper.bootstrap_from_go_champs(
          GoChampsScoreboard.Games.Bootstrapper.bootstrap(),
          "game-id",
          "token"
        )

      assert game.info.tournament_logo_url == "http://example.com/tournament_logo.png"
      assert length(game.info.sponsors) == 2

      [sponsor_a, sponsor_b] = game.info.sponsors
      assert sponsor_a.name == "Sponsor A"
      assert sponsor_a.link == "http://sponsora.com"
      assert sponsor_a.logo_url == "http://example.com/sponsor_a.png"

      assert sponsor_b.name == "Sponsor B"
      assert sponsor_b.link == "http://sponsorb.com"
      assert sponsor_b.logo_url == "http://example.com/sponsor_b.png"
    end

    test "defaults tournament logo and sponsors when not provided" do
      expect(@http_client, :get, fn url, headers, _opts ->
        assert url =~ "game-id"
        assert headers == [{"Authorization", "Bearer token"}]

        {:ok, %HTTPoison.Response{body: @response_body |> Poison.encode!(), status_code: 200}}
      end)

      expect(@http_client, :get, fn url, _headers, _opts ->
        assert url =~ "game-id/scoreboard-setting"

        {:ok, %HTTPoison.Response{body: %{"data" => nil} |> Poison.encode!(), status_code: 200}}
      end)

      game =
        Bootstrapper.bootstrap_from_go_champs(
          GoChampsScoreboard.Games.Bootstrapper.bootstrap(),
          "game-id",
          "token"
        )

      assert game.info.tournament_logo_url == ""
      assert game.info.sponsors == []
    end

    test "uses number field when provided" do
      expect(@http_client, :get, fn url, headers, _opts ->
        assert url =~ "game-id"
        assert headers == [{"Authorization", "Bearer token"}]

        {:ok,
         %HTTPoison.Response{
           body: @response_body_with_number |> Poison.encode!(),
           status_code: 200
         }}
      end)

      expect(@http_client, :get, fn url, _headers, _opts ->
        assert url =~ "game-id/scoreboard-setting"

        {:ok, %HTTPoison.Response{body: %{"data" => nil} |> Poison.encode!(), status_code: 200}}
      end)

      game =
        Bootstrapper.bootstrap_from_go_champs(
          GoChampsScoreboard.Games.Bootstrapper.bootstrap(),
          "game-id",
          "token"
        )

      assert game.info.number == "12345"
    end

    test "falls back to game_id when number is empty" do
      expect(@http_client, :get, fn url, headers, _opts ->
        assert url =~ "game-id"
        assert headers == [{"Authorization", "Bearer token"}]

        {:ok,
         %HTTPoison.Response{
           body: @response_body_with_empty_number |> Poison.encode!(),
           status_code: 200
         }}
      end)

      expect(@http_client, :get, fn url, _headers, _opts ->
        assert url =~ "game-id/scoreboard-setting"

        {:ok, %HTTPoison.Response{body: %{"data" => nil} |> Poison.encode!(), status_code: 200}}
      end)

      game =
        Bootstrapper.bootstrap_from_go_champs(
          GoChampsScoreboard.Games.Bootstrapper.bootstrap(),
          "game-id",
          "token"
        )

      assert game.info.number == "game-id"
    end

    test "falls back to game_id when number is null" do
      expect(@http_client, :get, fn url, headers, _opts ->
        assert url =~ "game-id"
        assert headers == [{"Authorization", "Bearer token"}]

        {:ok,
         %HTTPoison.Response{
           body: @response_body_with_null_number |> Poison.encode!(),
           status_code: 200
         }}
      end)

      expect(@http_client, :get, fn url, _headers, _opts ->
        assert url =~ "game-id/scoreboard-setting"

        {:ok, %HTTPoison.Response{body: %{"data" => nil} |> Poison.encode!(), status_code: 200}}
      end)

      game =
        Bootstrapper.bootstrap_from_go_champs(
          GoChampsScoreboard.Games.Bootstrapper.bootstrap(),
          "game-id",
          "token"
        )

      assert game.info.number == "game-id"
    end
  end
end
