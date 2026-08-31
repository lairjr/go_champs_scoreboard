defmodule GoChampsScoreboard.ApiClientTest do
  use ExUnit.Case
  alias GoChampsScoreboard.ApiClient

  import Mox

  setup :verify_on_exit!

  @http_client GoChampsScoreboard.HTTPClientMock
  @test_config http_client: @http_client, url: "url.com"

  defp game_response(permissions) do
    %{
      "data" => %{
        "id" => "game-id",
        "meta" => %{"permissions" => permissions}
      }
    }
  end

  describe "get_game" do
    test "returns response from API" do
      response_body = %{
        "id" => "game-id",
        "away_team" => %{
          "name" => "Away team"
        },
        "home_team" => %{
          "name" => "Home team"
        }
      }

      expect(@http_client, :get, fn url, headers, _opts ->
        assert url == "url.comv1/games/game-id"
        assert headers == [{"Authorization", "Bearer token"}]

        {:ok, %HTTPoison.Response{body: response_body |> Poison.encode!(), status_code: 200}}
      end)

      assert {:ok,
              %{
                "id" => "game-id",
                "away_team" => %{
                  "name" => "Away team"
                },
                "home_team" => %{
                  "name" => "Home team"
                }
              }} = ApiClient.get_game("game-id", "token", @test_config)
    end
  end

  describe "get_game_for_operation" do
    test "returns response when the caller has game:operate" do
      expect(@http_client, :get, fn url, headers, _opts ->
        assert url == "url.comv1/games/game-id"
        assert headers == [{"Authorization", "Bearer token"}]

        {:ok,
         %HTTPoison.Response{
           body: game_response(["game:operate"]) |> Poison.encode!(),
           status_code: 200
         }}
      end)

      assert {:ok, %{"data" => %{"id" => "game-id"}}} =
               ApiClient.get_game_for_operation("game-id", "token", @test_config)
    end

    test "denies access when permissions do not include game:operate" do
      expect(@http_client, :get, fn _url, _headers, _opts ->
        {:ok,
         %HTTPoison.Response{
           body: game_response(["tournament:manage"]) |> Poison.encode!(),
           status_code: 200
         }}
      end)

      assert {:error, :unauthorized} =
               ApiClient.get_game_for_operation("game-id", "token", @test_config)
    end

    test "denies access when permissions are empty" do
      expect(@http_client, :get, fn _url, _headers, _opts ->
        {:ok, %HTTPoison.Response{body: game_response([]) |> Poison.encode!(), status_code: 200}}
      end)

      assert {:error, :unauthorized} =
               ApiClient.get_game_for_operation("game-id", "token", @test_config)
    end

    test "denies access when the response carries no meta" do
      expect(@http_client, :get, fn _url, _headers, _opts ->
        {:ok,
         %HTTPoison.Response{
           body: %{"data" => %{"id" => "game-id"}} |> Poison.encode!(),
           status_code: 200
         }}
      end)

      assert {:error, :unauthorized} =
               ApiClient.get_game_for_operation("game-id", "token", @test_config)
    end

    test "propagates a transport failure" do
      expect(@http_client, :get, fn _url, _headers, _opts ->
        {:error, %HTTPoison.Error{reason: :timeout}}
      end)

      assert {:error, "something went wrong"} =
               ApiClient.get_game_for_operation("game-id", "token", @test_config)
    end
  end

  describe "get_scoreboard_setting" do
    test "returns response from API" do
      response_body = %{
        "id" => "game-id",
        "view" => "basketbal-basic"
      }

      expect(@http_client, :get, fn url, _headers, _opts ->
        assert url =~ "game-id/scoreboard-setting"

        {:ok, %HTTPoison.Response{body: response_body |> Poison.encode!(), status_code: 200}}
      end)

      assert {:ok,
              %{
                "id" => "game-id",
                "view" => "basketbal-basic"
              }} = ApiClient.get_scoreboard_setting("game-id", @test_config)
    end
  end
end
