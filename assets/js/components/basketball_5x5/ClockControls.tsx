import React from 'react';
import { GameClockState, LiveState, TeamState } from '../../types';
import { invokeButtonClickRef } from '../../shared/invokeButtonClick';
import { formatTime } from '../../shared/contentHelpers';
import { useTranslation } from '../../hooks/useTranslation';
import { isClockButtonsDisabled } from './clockControlsHelpers';

interface ClockControlsProps {
  away_team: TeamState;
  home_team: TeamState;
  clock_state: GameClockState;
  live_state: LiveState;
  pushEvent: (event: string, payload: any) => void;
}

interface InGameClockControlsProps {
  clock_state: GameClockState;
  away_team: TeamState;
  home_team: TeamState;
  clockButtonsDisabled: boolean;
  isClockRunning: boolean;
  isTimeZero: boolean;
  endQuarterButtonDisabled: boolean;
  clockEventHandlers: {
    pauseStart: () => void;
    updateTime: (operation: string) => void;
    endQuarter: () => void;
  };
  pushEvent: (event: string, payload: any) => void;
  buttonPauseStart: React.RefObject<HTMLButtonElement | null>;
}

interface EndGameClockControlsProps {
  clockButtonsDisabled: boolean;
  clockEventHandlers: {
    endGame: () => void;
  };
}

const LoseTimeoutButton = ({
  teamType,
  disabled,
  pushEvent,
}: {
  teamType: string;
  disabled: boolean;
  pushEvent: (event: string, payload: any) => void;
}) => {
  const { t } = useTranslation();

  return (
    <button
      className="button is-danger is-fullwidth"
      onClick={() =>
        pushEvent('update-team-stat', {
          'stat-id': 'lost_timeouts',
          'team-type': teamType,
          operation: 'increment',
        })
      }
      disabled={disabled}
    >
      {t('basketball.clock.loseTimeout')}
    </button>
  );
};

const TimeoutButton = ({
  teamType,
  disabled,
  pushEvent,
}: {
  teamType: string;
  disabled: boolean;
  pushEvent: (event: string, payload: any) => void;
}) => {
  const { t } = useTranslation();

  return (
    <button
      className="button is-info is-fullwidth"
      onClick={() =>
        pushEvent('update-team-stat', {
          'stat-id': 'timeouts',
          'team-type': teamType,
          operation: 'increment',
        })
      }
      disabled={disabled}
    >
      {t('basketball.clock.timeout')}
    </button>
  );
};

const HeadCoachChallengeButton = ({
  teamType,
  disabled,
  pushEvent,
}: {
  teamType: string;
  disabled: boolean;
  pushEvent: (event: string, payload: any) => void;
}) => {
  const { t } = useTranslation();

  return (
    <button
      className="button is-info is-fullwidth"
      onClick={() =>
        pushEvent('update-team-stat', {
          'stat-id': 'head_coach_challenge',
          'team-type': teamType,
          operation: 'increment',
        })
      }
      disabled={disabled}
    >
      {t('basketball.clock.headCoachChallenge')}
    </button>
  );
};

const TimeControl = ({
  label,
  tooltip,
  onClick,
  disabled,
}: {
  label: string;
  tooltip: string;
  onClick: () => void;
  disabled: boolean;
}) => (
  <button
    className="button is-info has-tooltip is-fullwidth"
    data-tooltip={tooltip}
    onClick={onClick}
    disabled={disabled}
    aria-label={label}
  >
    {label}
  </button>
);

const isHeadCoachChallengeButtonDisabled = (
  team: TeamState,
  clockButtonsDisabled: boolean,
): boolean => {
  // Base disable condition
  if (clockButtonsDisabled) return true;

  // Disable if head coach challenge has already been used
  return team.stats_values['head_coach_challenge'] >= 1;
};

const isTimeoutButtonDisabled = (
  team: TeamState,
  clock_state: GameClockState,
  clockButtonsDisabled: boolean,
): boolean => {
  // Base disable condition
  if (clockButtonsDisabled) return true;

  const period = clock_state.period;

  // First half (periods 1-2): max 2 timeouts
  if (period === 1 || period === 2) {
    const firstHalfTimeouts =
      (team.period_stats['1']?.timeouts || 0) +
      (team.period_stats['2']?.timeouts || 0);
    return firstHalfTimeouts >= 2;
  }

  // Second half (periods 3-4): max 3 timeouts
  if (period === 3 || period === 4) {
    const secondHalfTimeouts =
      (team.period_stats['3']?.timeouts || 0) +
      (team.period_stats['4']?.timeouts || 0) +
      (team.period_stats['3']?.lost_timeouts || 0) +
      (team.period_stats['4']?.lost_timeouts || 0);
    return secondHalfTimeouts >= 3;
  }

  // Overtime (period >= 5): max 1 timeout per overtime period
  if (period >= 5) {
    const overtimeTimeouts =
      team.period_stats[period.toString()]?.timeouts || 0;
    return overtimeTimeouts >= 1;
  }

  return false;
};

const shouldShowLoseTimeoutButton = (
  team: TeamState,
  clock_state: GameClockState,
): boolean => {
  const secondHalfTimeouts =
    (team.period_stats['3']?.timeouts || 0) +
    (team.period_stats['4']?.timeouts || 0) +
    (team.period_stats['3']?.lost_timeouts || 0) +
    (team.period_stats['4']?.lost_timeouts || 0);

  return (
    clock_state.period === 4 &&
    clock_state.time <= 120 &&
    secondHalfTimeouts === 0
  );
};

function InGameClockControls({
  clock_state,
  home_team,
  away_team,
  clockButtonsDisabled,
  isClockRunning,
  isTimeZero,
  endQuarterButtonDisabled,
  clockEventHandlers,
  pushEvent,
  buttonPauseStart,
}: InGameClockControlsProps) {
  const { t } = useTranslation();

  const samePeriodAsLastAction =
    clock_state.last_action_period !== null &&
    clock_state.last_action_time !== null &&
    clock_state.period === clock_state.last_action_period;

  const isRewindOneBlocked =
    samePeriodAsLastAction &&
    clock_state.time + 1 >= clock_state.last_action_time!;

  const isRewindSixtyBlocked =
    samePeriodAsLastAction &&
    clock_state.time + 60 >= clock_state.last_action_time!;

  return (
    <div className="columns is-multiline">
      <div className="column is-4">
        {shouldShowLoseTimeoutButton(home_team, clock_state) ? (
          <LoseTimeoutButton
            teamType="home"
            disabled={clockButtonsDisabled}
            pushEvent={pushEvent}
          />
        ) : (
          <TimeoutButton
            teamType="home"
            disabled={isTimeoutButtonDisabled(
              home_team,
              clock_state,
              clockButtonsDisabled,
            )}
            pushEvent={pushEvent}
          />
        )}
      </div>

      <div className="column is-4">
        <span className="chip-label">{clock_state.period}</span>
      </div>

      <div className="column is-4">
        {shouldShowLoseTimeoutButton(away_team, clock_state) ? (
          <LoseTimeoutButton
            teamType="away"
            disabled={clockButtonsDisabled}
            pushEvent={pushEvent}
          />
        ) : (
          <TimeoutButton
            teamType="away"
            disabled={isTimeoutButtonDisabled(
              away_team,
              clock_state,
              clockButtonsDisabled,
            )}
            pushEvent={pushEvent}
          />
        )}
      </div>

      <div className="column is-2">
        <TimeControl
          label="<<"
          tooltip={t('basketball.clock.tooltips.minusOneMinute')}
          onClick={() => clockEventHandlers.updateTime('increment60')}
          disabled={clockButtonsDisabled || isRewindSixtyBlocked}
        />
      </div>
      <div className="column is-2">
        <TimeControl
          label="<"
          tooltip={t('basketball.clock.tooltips.minusOneSecond')}
          onClick={() => clockEventHandlers.updateTime('increment')}
          disabled={clockButtonsDisabled || isRewindOneBlocked}
        />
      </div>
      <div className="column is-4">
        <span className="chip-label">{formatTime(clock_state.time)}</span>
      </div>
      <div className="column is-2">
        <TimeControl
          label=">"
          tooltip={t('basketball.clock.tooltips.plusOneSecond')}
          onClick={() => clockEventHandlers.updateTime('decrement')}
          disabled={clockButtonsDisabled}
        />
      </div>
      <div className="column is-2">
        <TimeControl
          label=">>"
          tooltip={t('basketball.clock.tooltips.plusOneMinute')}
          onClick={() => clockEventHandlers.updateTime('decrement60')}
          disabled={clockButtonsDisabled}
        />
      </div>

      <div className="column is-2">
        <HeadCoachChallengeButton
          teamType="home"
          disabled={isHeadCoachChallengeButtonDisabled(
            home_team,
            clockButtonsDisabled,
          )}
          pushEvent={pushEvent}
        />
      </div>

      <div className="column is-8">
        {isTimeZero ? (
          <button
            className="button is-warning is-fullwidth"
            onClick={clockEventHandlers.endQuarter}
            disabled={endQuarterButtonDisabled}
          >
            {t('basketball.clock.endQuarter')}
          </button>
        ) : (
          <button
            ref={buttonPauseStart}
            className="button is-info is-fullwidth"
            onClick={clockEventHandlers.pauseStart}
            disabled={clockButtonsDisabled}
          >
            <span className="shortcut">SPACE</span>
            {isClockRunning
              ? t('basketball.clock.pause')
              : t('basketball.clock.start')}
          </button>
        )}
      </div>

      <div className="column is-2">
        <HeadCoachChallengeButton
          teamType="away"
          disabled={isHeadCoachChallengeButtonDisabled(
            away_team,
            clockButtonsDisabled,
          )}
          pushEvent={pushEvent}
        />
      </div>
    </div>
  );
}

function EndGameClockControls({
  clockButtonsDisabled,
  clockEventHandlers,
}: EndGameClockControlsProps) {
  const { t } = useTranslation();

  return (
    <div className="columns is-multiline">
      <div className="column is-12">
        <button
          className="button is-danger is-fullwidth"
          onClick={clockEventHandlers.endGame}
          disabled={clockButtonsDisabled}
          style={{ height: '173px' }}
        >
          {t('basketball.clock.endGame')}
        </button>
      </div>
    </div>
  );
}

function ClockControls({
  away_team,
  home_team,
  clock_state,
  live_state,
  pushEvent,
}: ClockControlsProps) {
  const buttonPauseStart = React.useRef<HTMLButtonElement | null>(null);

  const clockButtonsDisabled = isClockButtonsDisabled(
    live_state,
    clock_state,
    home_team,
    away_team,
  );
  const isGameTied =
    away_team.stats_values['points'] === home_team.stats_values['points'];
  const endQuarterButtonDisabled = clock_state.period >= 4 && !isGameTied;
  const isClockRunning = clock_state.state === 'running';
  const isTimeZero = clock_state.time === 0;
  const displayEndGameControls =
    clock_state.period >= 4 && !isGameTied && isTimeZero;

  // Event handlers
  const clockEventHandlers = {
    pauseStart: () => {
      const newState = isClockRunning ? 'paused' : 'running';
      pushEvent('update-clock-state', { state: newState });
    },

    updateTime: (operation: string) => {
      pushEvent('update-clock-time-and-period', {
        property: 'time',
        operation,
      });
    },

    endQuarter: () => {
      pushEvent('end-period', {});
    },

    endGame: () => {
      pushEvent('end-game', {});
    },
  };

  React.useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent) => {
      // Check if any modal is currently open
      const isModalOpen = document.querySelector('.modal.is-active') !== null;
      if (isModalOpen) return;

      if (event.key === ' ') {
        event.preventDefault();
        invokeButtonClickRef(buttonPauseStart);
      }
    };

    document.addEventListener('keydown', handleKeyDown);
    return () => document.removeEventListener('keydown', handleKeyDown);
  }, []);

  return (
    <div className="controls">
      {displayEndGameControls ? (
        <EndGameClockControls
          clockButtonsDisabled={clockButtonsDisabled}
          clockEventHandlers={{ endGame: clockEventHandlers.endGame }}
        />
      ) : (
        <InGameClockControls
          clock_state={clock_state}
          home_team={home_team}
          away_team={away_team}
          clockButtonsDisabled={clockButtonsDisabled}
          isClockRunning={isClockRunning}
          isTimeZero={isTimeZero}
          endQuarterButtonDisabled={endQuarterButtonDisabled}
          clockEventHandlers={{
            pauseStart: clockEventHandlers.pauseStart,
            updateTime: clockEventHandlers.updateTime,
            endQuarter: clockEventHandlers.endQuarter,
          }}
          pushEvent={pushEvent}
          buttonPauseStart={buttonPauseStart}
        />
      )}
    </div>
  );
}

export default ClockControls;
