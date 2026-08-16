defmodule GoChampsScoreboard.Sports.Basketball.Reports.FibaScoresheet.EndPeriodProcessor do
  @moduledoc """
  Processes the end of a period in the FIBA scoresheet.
  """

  alias GoChampsScoreboard.Sports.Basketball.Reports.FibaScoresheet.TeamManager
  alias GoChampsScoreboard.Sports.Basketball.Reports.FibaScoresheet.FibaScoresheetManager
  alias GoChampsScoreboard.Sports.Basketball.Reports.FibaScoresheet
  alias GoChampsScoreboard.Events.EventLog

  @spec process(EventLog.t(), FibaScoresheet.t()) :: FibaScoresheet.t()
  def process(event_log, data) do
    updated_home_team =
      data
      |> FibaScoresheetManager.find_team("home")
      |> TeamManager.mark_score_as_last_of_period()
      |> TeamManager.mark_fouls_as_last_of_half(event_log.game_clock_period)

    updated_away_team =
      data
      |> FibaScoresheetManager.find_team("away")
      |> TeamManager.mark_score_as_last_of_period()
      |> TeamManager.mark_fouls_as_last_of_half(event_log.game_clock_period)

    updated_info = %{
      data.info
      | ended_periods: Enum.uniq([event_log.game_clock_period | data.info.ended_periods])
    }

    data
    |> FibaScoresheetManager.update_team("home", updated_home_team)
    |> FibaScoresheetManager.update_team("away", updated_away_team)
    |> FibaScoresheetManager.update_info(updated_info)
  end
end
