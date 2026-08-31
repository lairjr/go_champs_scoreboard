defmodule GoChampsScoreboard.ApiClient do
  require Logger
  alias HTTPoison

  @games_path "v1/games"

  @operate_permission "game:operate"

  @callback get_game(String.t(), String.t()) :: {:ok, any()} | {:error, any()}
  def get_game(game_id, token, config \\ system_config()) do
    url = Keyword.get(config, :url, "") <> @games_path <> "/" <> game_id
    http_client = Keyword.get(config, :http_client)

    Logger.info("[Get Game]: From Go Champs Api", url: url)

    headers = [{"Authorization", "Bearer #{token}"}]

    url
    |> http_client.get(headers, timeout: 10_000, recv_timeout: 10_000)
    |> log()
    |> handle_response()
  end

  @doc """
  Fetches a game and only succeeds when the caller may operate it.

  `GET /v1/games/:id` is a public endpoint: it answers 200 to anyone, and
  reports what the bearer of the token may do in `data.meta.permissions`.
  Authorization is therefore decided here, from the body, and not from the
  status code as it was with the former `verify-access` probe.

  Anything other than an explicit `game:operate` grant — a missing `meta`, an
  anonymous request, an empty list — denies access.
  """
  @spec get_game_for_operation(String.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, any()}
  def get_game_for_operation(game_id, token, config \\ system_config()) do
    with {:ok, response} <- get_game(game_id, token, config) do
      if can_operate?(response) do
        {:ok, response}
      else
        Logger.warning("[Get Game]: Caller may not operate game", game_id: game_id)

        {:error, :unauthorized}
      end
    end
  end

  defp can_operate?(%{"data" => %{"meta" => %{"permissions" => permissions}}})
       when is_list(permissions),
       do: @operate_permission in permissions

  defp can_operate?(_response), do: false

  def get_scoreboard_setting(game_id, config \\ system_config()) do
    url = Keyword.get(config, :url, "") <> @games_path <> "/" <> game_id <> "/scoreboard-setting"
    http_client = Keyword.get(config, :http_client)

    Logger.info("[Get Game Scoreboard Setting]: From Go Champs Api", url: url)

    url
    |> http_client.get([], timeout: 10_000, recv_timeout: 10_000)
    |> log()
    |> handle_response()
  end

  defp log(response) do
    Logger.info("[Get Game]: Response from Go Champs Api", response: response)
    response
  end

  defp handle_response({:ok, %HTTPoison.Response{body: body, status_code: 200}}),
    do: {:ok, Poison.decode!(body)}

  defp handle_response(_), do: {:error, "something went wrong"}

  defp system_config(), do: Application.get_env(:go_champs_scoreboard, :http_client)
end
