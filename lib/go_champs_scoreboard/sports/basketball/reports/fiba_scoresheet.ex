defmodule GoChampsScoreboard.Sports.Basketball.Reports.FibaScoresheet do
  defmodule Foul do
    @moduledoc """
    Foul struct for FIBA scoresheet.
    """

    # Define valid foul types
    # Personal, Technical, Anti Sportsmanship (U), Disqualifying, Disqualifying Fighting (F), Technical due other persons (B)
    @valid_fouls_types ["P", "T", "U", "D", "F", "B"]

    @valid_extra_actions ["1", "2", "3", "C"]

    @type t :: %__MODULE__{
            type: String.t(),
            period: Integer.t(),
            extra_action: String.t(),
            is_last_of_half: boolean()
          }

    defstruct [
      :type,
      :period,
      :extra_action,
      :is_last_of_half
    ]

    @doc """
    Creates a new PointScore struct with validation
    """
    def new(attrs) do
      type = Map.get(attrs, :type)
      extra_action = Map.get(attrs, :extra_action)

      if type in @valid_fouls_types and extra_action in @valid_extra_actions do
        struct(__MODULE__, attrs)
      else
        {:error,
         "Invalid foul type: #{type}. Must be one of: #{Enum.join(@valid_fouls_types, ", ")}"}
      end
    end
  end

  defmodule Player do
    @moduledoc """
    Player struct for FIBA scoresheet.
    """

    @type t :: %__MODULE__{
            id: String.t(),
            name: String.t(),
            number: String.t(),
            fouls: list(Foul.t()),
            license_number: String.t(),
            signature: String.t() | nil,
            has_started: boolean(),
            has_played: boolean(),
            first_played_period: integer(),
            is_captain: boolean()
          }

    defstruct [
      :id,
      :name,
      :number,
      :fouls,
      :license_number,
      :signature,
      :has_started,
      :has_played,
      :first_played_period,
      :is_captain
    ]
  end

  defmodule Coach do
    @moduledoc """
    Coach struct for FIBA scoresheet.
    """

    @type t :: %__MODULE__{
            id: String.t(),
            name: String.t(),
            signature: String.t() | nil,
            fouls: list(Foul.t())
          }

    defstruct [
      :id,
      :name,
      :signature,
      :fouls
    ]
  end

  defmodule Official do
    @moduledoc """
    Official struct for FIBA scoresheet.
    """

    @type t :: %__MODULE__{
            id: String.t(),
            name: String.t(),
            signature: String.t() | nil,
            federation: String.t() | nil
          }

    defstruct [
      :id,
      :name,
      :signature,
      :federation
    ]
  end

  defmodule PointScore do
    @moduledoc """
    PointScore struct for FIBA scoresheet.
    """

    # Define valid point types
    @valid_point_types ["FT", "2PT", "3PT"]

    @type t :: %__MODULE__{
            type: String.t(),
            player_number: Integer.t(),
            period: Integer.t(),
            is_last_of_period: boolean()
          }

    defstruct [
      :type,
      :player_number,
      :period,
      :is_last_of_period
    ]

    @doc """
    Creates a new PointScore struct with validation
    """
    def new(attrs) do
      type = Map.get(attrs, :type)

      if type in @valid_point_types do
        struct(__MODULE__, attrs)
      else
        {:error,
         "Invalid point type: #{type}. Must be one of: #{Enum.join(@valid_point_types, ", ")}"}
      end
    end
  end

  defmodule PlayerPointsSummary do
    @moduledoc """
    PlayerPointsSummary struct for FIBA scoresheet points summary page.
    """

    @type t :: %__MODULE__{
            player_number: Integer.t(),
            points_per_period: %{Integer.t() => Integer.t()},
            extra: integer(),
            total: integer(),
            last_scored_period: Integer.t() | nil
          }

    defstruct [
      :player_number,
      :points_per_period,
      :extra,
      :total,
      :last_scored_period
    ]
  end

  defmodule Timeout do
    @moduledoc """
    Timeout struct for FIBA scoresheet.
    """

    @type t :: %__MODULE__{
            period: Integer.t(),
            minute: Integer.t(),
            lost: boolean()
          }

    defstruct [
      :period,
      :minute,
      :lost
    ]
  end

  defmodule HeadCoachChallenge do
    @moduledoc """
    HeadCoachChallenge struct for FIBA scoresheet.
    """

    @type t :: %__MODULE__{
            period: Integer.t(),
            minute: Integer.t()
          }

    defstruct [
      :period,
      :minute
    ]
  end

  defmodule Team do
    @moduledoc """
    Team struct for FIBA scoresheet.
    """

    @type t :: %__MODULE__{
            name: String.t(),
            players: list(Player.t()),
            coach: Coach.t(),
            assistant_coach: Coach.t(),
            all_fouls: list(Foul.t()),
            timeouts: list(Timeout.t()),
            running_score: %{Integer.t() => PointScore.t()},
            head_coach_challenges: list(HeadCoachChallenge.t()),
            score: integer(),
            has_walkover: boolean(),
            points_by_period: %{integer() => integer()},
            points_summary: %{integer() => PlayerPointsSummary.t()}
          }

    defstruct [
      :name,
      :players,
      :coach,
      :assistant_coach,
      :all_fouls,
      :timeouts,
      :running_score,
      :head_coach_challenges,
      :score,
      :has_walkover,
      :points_by_period,
      :points_summary
    ]
  end

  defmodule Info do
    @moduledoc """
    Info struct for FIBA scoresheet.
    """

    @type sponsor :: %{
            name: String.t(),
            link: String.t(),
            logo_url: String.t()
          }

    @type t :: %__MODULE__{
            number: String.t(),
            location: String.t(),
            city: String.t(),
            datetime: DateTime.t(),
            tournament_name: String.t(),
            tournament_slug: String.t(),
            tournament_logo_url: String.t(),
            organization_name: String.t(),
            organization_slug: String.t(),
            organization_logo_url: String.t(),
            actual_start_datetime: DateTime.t() | nil,
            actual_end_datetime: DateTime.t() | nil,
            initial_period_time: integer() | nil,
            game_report: String.t() | nil,
            web_url: String.t() | nil,
            sponsors: [sponsor()],
            ended_periods: [integer()]
          }

    defstruct [
      :number,
      :location,
      :city,
      :datetime,
      :tournament_name,
      :tournament_slug,
      :tournament_logo_url,
      :organization_name,
      :organization_slug,
      :organization_logo_url,
      :actual_start_datetime,
      :actual_end_datetime,
      :initial_period_time,
      :game_report,
      :web_url,
      :sponsors,
      ended_periods: []
    ]
  end

  defmodule Protest do
    @moduledoc """
    Protest struct for FIBA scoresheet.
    """

    @type t :: %__MODULE__{
            player_name: String.t(),
            state: :no_protest | :protest_filed,
            signature: String.t() | nil
          }

    defstruct [
      :player_name,
      :state,
      :signature
    ]
  end

  @type t :: %__MODULE__{
          game_id: String.t(),
          tournament_name: String.t(),
          info: Info.t(),
          team_a: Team.t(),
          team_b: Team.t(),
          scorer: Official.t(),
          assistant_scorer: Official.t(),
          timekeeper: Official.t(),
          shot_clock_operator: Official.t(),
          crew_chief: Official.t(),
          umpire_1: Official.t(),
          umpire_2: Official.t(),
          protest: Protest.t()
        }

  defstruct [
    :game_id,
    :tournament_name,
    :info,
    :team_a,
    :team_b,
    :scorer,
    :assistant_scorer,
    :timekeeper,
    :shot_clock_operator,
    :crew_chief,
    :umpire_1,
    :umpire_2,
    :protest
  ]
end
