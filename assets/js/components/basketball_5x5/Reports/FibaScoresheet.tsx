import React, { useMemo } from 'react';
import { useTranslation } from 'react-i18next';
import {
  Document,
  Page,
  Text,
  View,
  StyleSheet,
  Image,
} from '@react-pdf/renderer';
import RunningScoreBox from './FibaScoresheet/RunningScoreBox';
import TeamBox from './FibaScoresheet/TeamBox';
import OfficialsBox from './FibaScoresheet/OfficialsBox';
import FiscalsBox from './FibaScoresheet/FiscalsBox';
import HeaderBox from './FibaScoresheet/HeaderBox';
import PointsSummaryPage from './FibaScoresheet/PointsSummaryPage';
import { textColorForPeriod } from './FibaScoresheet/styles';
import PageHeader from './Shared/PageHeader';

export interface PlayerFoul {
  type: 'P' | 'T' | 'U' | 'D' | 'GD';
  period: number;
  extra_action?: '1' | '2' | '3' | 'C' | '';
  is_last_of_half: boolean;
}

export interface CoachFoul {
  type: 'C' | 'D' | 'F' | 'B' | 'BD' | 'GD';
  period: number;
  extra_action?: '1' | '2' | '3' | 'C' | '';
  is_last_of_half: boolean;
}

export interface Coach {
  name: string;
  fouls: CoachFoul[];
}

export interface Player {
  name: string;
  number: number;
  fouls: PlayerFoul[];
  license_number: string;
  has_started: boolean;
  has_played: boolean;
  is_captain: boolean;
  first_played_period: number;
}

export interface Timeout {
  minute: number;
  period: number;
  lost: boolean;
}

export interface ScoreMark {
  type: 'FT' | '2PT' | '3PT';
  player_number: number;
  period: number;
  is_last_of_period: boolean;
}

export interface PlayerPointsSummary {
  player_number: number;
  points_per_period: { [period: string]: number };
  extra: number;
  total: number;
  last_scored_period: number | null;
}

export interface RunningScore {
  [score: number]: ScoreMark;
}

export interface Official {
  id: string;
  name: string;
  signature?: string;
  federation?: string;
}

export interface Protest {
  state: 'no_protest' | 'protest_filed';
  player_name: string;
  signature?: string;
}

export interface HeadCoachChallenge {
  period: number;
  minute: number;
}

export interface Team {
  name: string;
  players: Player[];
  timeouts: Timeout[];
  head_coach_challenges: HeadCoachChallenge[];
  running_score: RunningScore;
  coach: Coach;
  assistant_coach: Coach;
  score: number;
  all_fouls: PlayerFoul[];
  has_walkover: boolean;
  points_by_period: { [period: string]: number };
  points_summary: { [player_number: number]: PlayerPointsSummary };
}

export interface Sponsor {
  name: string;
  logo_url: string;
}

export interface Info {
  number: string;
  location: string;
  city: string;
  datetime: string;
  tournament_name: string;
  tournament_slug: string;
  tournament_logo_url: string;
  organization_name: string;
  organization_slug: string;
  organization_logo_url: string;
  actual_start_datetime: string;
  actual_end_datetime: string;
  sponsors: Sponsor[];
  game_report: string;
  web_url: string;
  ended_periods: number[];
}

const styles = StyleSheet.create({
  page: {
    flexDirection: 'column',
    backgroundColor: '#FFFFFF',
    padding: '12px 12px 20px 12px',
    fontSize: 8,
  },
  main: {
    border: '2px solid #000',
    margin: 'auto',
    height: '95%',
    width: '100%',
    header: {
      borderBottom: '2px solid #000',
      height: '40px',
    },
    teamsAndRunningScoreContainer: {
      display: 'flex',
      flexDirection: 'row',
      justifyContent: 'space-between',
      containerLeft: {
        borderRight: '1px solid #000',
        flex: '1 1',
      },
      containerRight: {
        borderLeft: '1px solid #000',
        flex: '1 1',
      },
    },
  },
  periods: {
    display: 'flex',
    borderTop: '1px solid #000',
    borderBottom: '1px solid #000',
    padding: '3px 2px',
    row: {
      display: 'flex',
      flexDirection: 'row',
      justifyContent: 'space-between',
      padding: '2px 0',
      column: {
        flex: '1 1',
        display: 'flex',
      },
    },
    period: {
      display: 'flex',
      flexDirection: 'row',
      justifyContent: 'space-between',
      padding: '0 5px',
      quarter: {
        display: 'flex',
        flex: '1 1',
      },
      cell: {
        display: 'flex',
        flexDirection: 'row',
        justifyContent: 'space-between',
        flex: '1 1',
      },
      winningTeamLabel: {
        display: 'flex',
        width: '83px',
      },
      winningTeamName: {
        display: 'flex',
        flex: '1 1',
        overflow: 'hidden',
        content: {
          maxLines: 1,
          textOverflow: 'ellipsis',
        },
      },
    },
  },
  protest: {
    padding: '3px 5px',
    row: {
      display: 'flex',
      flexDirection: 'row',
      justifyContent: 'space-between',
      cell: {
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        padding: '2px',
        signatureBox: {
          padding: '1px',
          width: '60px',
          height: '12px',
          borderBottom: '1px solid #000',
        },
      },
    },
  },
});

interface Period {
  isQuarterCentered?: boolean;
  period: number;
  periodLabel: string;
  teamAScore: number;
  teamBScore: number;
  shouldDisplayZero?: boolean;
}

function Period({
  period,
  periodLabel,
  teamAScore,
  teamBScore,
  isQuarterCentered = false,
  shouldDisplayZero = false,
}: Period) {
  const quarterStyle = isQuarterCentered
    ? {
        ...styles.periods.period.quarter,
        justifyContent: 'center',
        alignItems: 'center',
      }
    : styles.periods.period.quarter;
  const defaultNoScoreDisplay = shouldDisplayZero ? 0 : '-';
  return (
    <View style={styles.periods.period}>
      <View style={quarterStyle}>
        <Text>{periodLabel}</Text>
      </View>
      <View style={styles.periods.period.cell}>
        <Text>A</Text>
        <Text style={textColorForPeriod(period)}>
          {teamAScore ? teamAScore : defaultNoScoreDisplay}
        </Text>
        <Text>B</Text>
        <Text style={textColorForPeriod(period)}>
          {teamBScore ? teamBScore : defaultNoScoreDisplay}
        </Text>
      </View>
    </View>
  );
}

export function sumExtraTimeTotalScore(team: Team) {
  return Object.entries(team.points_by_period).reduce(
    (total, [period, points]) => {
      const periodNumber = parseInt(period, 10);
      if (periodNumber > 4) {
        return total + points;
      }
      return total;
    },
    0,
  );
}

function Periods({
  teamA,
  teamB,
  isGameEnded,
}: {
  teamA: Team;
  teamB: Team;
  isGameEnded: boolean;
}) {
  const { t } = useTranslation();
  const teamAExtraTimeScore = sumExtraTimeTotalScore(teamA);
  const teamBExtraTimeScore = sumExtraTimeTotalScore(teamB);
  const hasWalkoverTeam = teamA.has_walkover || teamB.has_walkover;
  return (
    <View style={styles.periods}>
      <View style={styles.periods.row}>
        <View style={styles.periods.row.column}>
          <Period
            period={1}
            periodLabel={`${t(
              'basketball.reports.fibaScoresheet.periods.quarter',
            )} 1`}
            teamAScore={teamA.points_by_period['1']}
            teamBScore={teamB.points_by_period['1']}
            shouldDisplayZero={isGameEnded}
          />
        </View>
        <View style={styles.periods.row.column}>
          <Period
            period={2}
            periodLabel="2"
            isQuarterCentered
            teamAScore={teamA.points_by_period['2']}
            teamBScore={teamB.points_by_period['2']}
            shouldDisplayZero={isGameEnded}
          />
        </View>
      </View>
      <View style={styles.periods.row}>
        <View style={styles.periods.row.column}>
          <Period
            period={3}
            periodLabel={`${t(
              'basketball.reports.fibaScoresheet.periods.quarter',
            )} 3`}
            teamAScore={teamA.points_by_period['3']}
            teamBScore={teamB.points_by_period['3']}
            shouldDisplayZero={isGameEnded}
          />
        </View>
        <View style={styles.periods.row.column}>
          <Period
            period={4}
            periodLabel="4"
            isQuarterCentered
            teamAScore={teamA.points_by_period['4']}
            teamBScore={teamB.points_by_period['4']}
            shouldDisplayZero={isGameEnded}
          />
        </View>
      </View>
      <View style={styles.periods.row}>
        <View style={styles.periods.row.column}>
          <Period
            period={5}
            periodLabel={t(
              'basketball.reports.fibaScoresheet.periods.extraTime',
            )}
            teamAScore={hasWalkoverTeam ? 0 : teamAExtraTimeScore}
            teamBScore={hasWalkoverTeam ? 0 : teamBExtraTimeScore}
          />
        </View>
        <View style={styles.periods.row.column}></View>
      </View>
    </View>
  );
}

function EndResults({
  teamA,
  teamB,
  isGameEnded,
}: {
  teamA: Team;
  teamB: Team;
  isGameEnded: boolean;
}) {
  const { t } = useTranslation();
  const winnerTeam = teamA.score > teamB.score ? teamA : teamB;
  return (
    <View style={styles.periods}>
      <View style={styles.periods.row}>
        <View style={styles.periods.row.column}>
          <Period
            periodLabel={t('basketball.reports.fibaScoresheet.finalResult')}
            period={5}
            teamAScore={teamA.score}
            teamBScore={teamB.score}
            shouldDisplayZero={
              teamA.has_walkover || teamB.has_walkover || !isGameEnded
            }
          />
        </View>
        <View style={styles.periods.row.column}></View>
      </View>
      <View style={styles.periods.row}>
        <View style={styles.periods.row.column}>
          <View style={styles.periods.period}>
            <View style={styles.periods.period.winningTeamLabel}>
              <Text>{t('basketball.reports.fibaScoresheet.winningTeam')}</Text>
            </View>
            <View style={styles.periods.period.winningTeamName}>
              <Text style={styles.periods.period.winningTeamName.content}>
                {isGameEnded ? winnerTeam.name : ''}
              </Text>
            </View>
          </View>
        </View>
      </View>
    </View>
  );
}

function Protest({ protest }: { protest: Protest }) {
  const { t } = useTranslation();
  return (
    <View style={styles.protest}>
      <View style={styles.protest.row}>
        <View style={styles.protest.row.cell}>
          <Text>
            {t('basketball.reports.fibaScoresheet.protest.captainSignature')}
          </Text>
        </View>
        <View style={styles.protest.row.cell}>
          {protest.signature && (
            <View style={styles.protest.row.cell.signatureBox}>
              <Image
                src={protest.signature}
                style={{ width: '100%', height: '100%' }}
              />
            </View>
          )}
        </View>
      </View>
      <View style={styles.protest.row}>
        <View style={styles.protest.row.cell}>
          <Text>
            {t('basketball.reports.fibaScoresheet.protest.player')}:{' '}
            {protest.state === 'protest_filed' ? protest.player_name : 'N/A'}
          </Text>
        </View>
      </View>
    </View>
  );
}

function EndGame({ endDatetime }: { endDatetime: string }) {
  const { t } = useTranslation();
  const formattedEndDatetime = endDatetime
    ? new Date(endDatetime).toLocaleTimeString('pt-BR', {
        hour: '2-digit',
        minute: '2-digit',
      })
    : '';
  return (
    <View style={styles.periods}>
      <View style={styles.periods.row}>
        <View style={styles.periods.row.column}>
          <View style={styles.periods.period}>
            <View style={styles.periods.period.quarter}>
              <Text>{t('basketball.reports.fibaScoresheet.gameEndTime')}</Text>
            </View>
            <View style={styles.periods.period.cell}>
              <Text>{formattedEndDatetime}</Text>
            </View>
          </View>
        </View>
      </View>
    </View>
  );
}

export interface FibaScoresheetData {
  game_id: string;
  team_a: Team;
  team_b: Team;
  info: Info;
  scorer: Official;
  assistant_scorer: Official;
  timekeeper: Official;
  shot_clock_operator: Official;
  crew_chief: Official;
  umpire_1: Official;
  umpire_2: Official;
  protest: Protest;
}

interface FibaScoresheetProps {
  scoresheetData: FibaScoresheetData;
}

function ScoresheetPage({ scoresheetData }: FibaScoresheetProps) {
  return (
    <Page size="A4" style={styles.page}>
      <PageHeader
        organizationName={scoresheetData.info.organization_name}
        tournamentName={scoresheetData.info.tournament_name}
        tournamentLogoUrl={scoresheetData.info.tournament_logo_url}
        organizationLogoUrl={scoresheetData.info.organization_logo_url}
        sponsors={scoresheetData.info.sponsors}
        qrCodeUrl={scoresheetData.info.web_url}
      />
      <View style={styles.main}>
        <View style={styles.main.header}>
          <HeaderBox
            number={scoresheetData.info.number}
            crewChief={scoresheetData.crew_chief}
            umpire1={scoresheetData.umpire_1}
            umpire2={scoresheetData.umpire_2}
            datetime={scoresheetData.info.actual_start_datetime}
            location={scoresheetData.info.location}
            city={scoresheetData.info.city}
            teamAName={scoresheetData.team_a.name}
            teamBName={scoresheetData.team_b.name}
            isGameEnded={!!scoresheetData.info.actual_end_datetime}
          />
        </View>
        <View style={styles.main.teamsAndRunningScoreContainer}>
          <View style={styles.main.teamsAndRunningScoreContainer.containerLeft}>
            <TeamBox
              type="A"
              team={scoresheetData.team_a}
              isGameEnded={!!scoresheetData.info.actual_end_datetime}
            />
            <TeamBox
              type="B"
              team={scoresheetData.team_b}
              isGameEnded={!!scoresheetData.info.actual_end_datetime}
            />
            <OfficialsBox
              scorer={scoresheetData.scorer}
              assistantScorer={scoresheetData.assistant_scorer}
              timekeeper={scoresheetData.timekeeper}
              shotClockOperator={scoresheetData.shot_clock_operator}
              isGameEnded={!!scoresheetData.info.actual_end_datetime}
            />
            <FiscalsBox
              crewChief={scoresheetData.crew_chief}
              umpire1={scoresheetData.umpire_1}
              umpire2={scoresheetData.umpire_2}
              isGameEnded={!!scoresheetData.info.actual_end_datetime}
            />
          </View>
          <View
            style={styles.main.teamsAndRunningScoreContainer.containerRight}
          >
            <RunningScoreBox
              aTeamRunningScore={scoresheetData.team_a.running_score}
              aTeamLastScore={scoresheetData.team_a.score}
              bTeamRunningScore={scoresheetData.team_b.running_score}
              bTeamLastScore={scoresheetData.team_b.score}
              isGameEnded={!!scoresheetData.info.actual_end_datetime}
              hasWalkoverTeam={
                scoresheetData.team_a.has_walkover ||
                scoresheetData.team_b.has_walkover
              }
            />
            <Periods
              teamA={scoresheetData.team_a}
              teamB={scoresheetData.team_b}
              isGameEnded={!!scoresheetData.info.actual_end_datetime}
            />
            <EndResults
              teamA={scoresheetData.team_a}
              teamB={scoresheetData.team_b}
              isGameEnded={!!scoresheetData.info.actual_end_datetime}
            />
            <Protest protest={scoresheetData.protest} />
            <EndGame endDatetime={scoresheetData.info.actual_end_datetime} />
          </View>
        </View>
      </View>
    </Page>
  );
}

function ExtendedScoresheetPage({ scoresheetData }: FibaScoresheetProps) {
  return (
    <Page size="A4" style={styles.page}>
      <PageHeader
        organizationName={scoresheetData.info.organization_name}
        tournamentName={scoresheetData.info.tournament_name}
        tournamentLogoUrl={scoresheetData.info.tournament_logo_url}
        organizationLogoUrl={scoresheetData.info.organization_logo_url}
        sponsors={scoresheetData.info.sponsors}
        qrCodeUrl={scoresheetData.info.web_url}
      />
      <View style={styles.main}>
        <View style={styles.main.header}>
          <HeaderBox
            number={scoresheetData.info.number}
            crewChief={scoresheetData.crew_chief}
            umpire1={scoresheetData.umpire_1}
            umpire2={scoresheetData.umpire_2}
            datetime={scoresheetData.info.actual_start_datetime}
            location={scoresheetData.info.location}
            city={scoresheetData.info.city}
            teamAName={scoresheetData.team_a.name}
            teamBName={scoresheetData.team_b.name}
            isGameEnded={!!scoresheetData.info.actual_end_datetime}
          />
        </View>
        <View style={styles.main.teamsAndRunningScoreContainer}>
          <View style={styles.main.teamsAndRunningScoreContainer.containerLeft}>
            <TeamBox
              type="A"
              team={scoresheetData.team_a}
              isGameEnded={!!scoresheetData.info.actual_end_datetime}
            />
            <TeamBox
              type="B"
              team={scoresheetData.team_b}
              isGameEnded={!!scoresheetData.info.actual_end_datetime}
            />
            <OfficialsBox
              scorer={scoresheetData.scorer}
              assistantScorer={scoresheetData.assistant_scorer}
              timekeeper={scoresheetData.timekeeper}
              shotClockOperator={scoresheetData.shot_clock_operator}
              isGameEnded={!!scoresheetData.info.actual_end_datetime}
            />
            <FiscalsBox
              crewChief={scoresheetData.crew_chief}
              umpire1={scoresheetData.umpire_1}
              umpire2={scoresheetData.umpire_2}
              isGameEnded={!!scoresheetData.info.actual_end_datetime}
            />
          </View>
          <View
            style={styles.main.teamsAndRunningScoreContainer.containerRight}
          >
            <RunningScoreBox
              aTeamRunningScore={scoresheetData.team_a.running_score}
              aTeamLastScore={scoresheetData.team_a.score}
              bTeamRunningScore={scoresheetData.team_b.running_score}
              bTeamLastScore={scoresheetData.team_b.score}
              isGameEnded={!!scoresheetData.info.actual_end_datetime}
              hasWalkoverTeam={
                scoresheetData.team_a.has_walkover ||
                scoresheetData.team_b.has_walkover
              }
              startScore={161}
            />
            <Periods
              teamA={scoresheetData.team_a}
              teamB={scoresheetData.team_b}
              isGameEnded={!!scoresheetData.info.actual_end_datetime}
            />
            <EndResults
              teamA={scoresheetData.team_a}
              teamB={scoresheetData.team_b}
              isGameEnded={!!scoresheetData.info.actual_end_datetime}
            />
            <Protest protest={scoresheetData.protest} />
            <EndGame endDatetime={scoresheetData.info.actual_end_datetime} />
          </View>
        </View>
      </View>
    </Page>
  );
}

function GameReportPage({ scoresheetData }: FibaScoresheetProps) {
  const { t } = useTranslation();
  return (
    <Page size="A4" style={styles.page}>
      <PageHeader
        organizationName={scoresheetData.info.organization_name}
        tournamentName={scoresheetData.info.tournament_name}
        tournamentLogoUrl={scoresheetData.info.tournament_logo_url}
        organizationLogoUrl={scoresheetData.info.organization_logo_url}
        sponsors={scoresheetData.info.sponsors}
        qrCodeUrl={scoresheetData.info.web_url}
      />
      <View style={styles.main}>
        <View style={styles.main.header}>
          <HeaderBox
            number={scoresheetData.info.number}
            crewChief={scoresheetData.crew_chief}
            umpire1={scoresheetData.umpire_1}
            umpire2={scoresheetData.umpire_2}
            datetime={scoresheetData.info.actual_start_datetime}
            location={scoresheetData.info.location}
            city={scoresheetData.info.city}
            teamAName={scoresheetData.team_a.name}
            teamBName={scoresheetData.team_b.name}
            isGameEnded={!!scoresheetData.info.actual_end_datetime}
          />
        </View>
        <View
          style={{
            border: '2px solid #000',
            margin: '10px',
            padding: '15px',
            flex: 1,
          }}
        >
          <Text
            style={{
              fontSize: '11px',
              fontWeight: 'bold',
              marginBottom: '10px',
              textAlign: 'center',
            }}
          >
            {t('basketball.reports.fibaScoresheet.gameReport')}
          </Text>
          <Text
            style={{
              fontSize: '10px',
              lineHeight: 1.4,
              whiteSpace: 'pre-wrap',
            }}
          >
            {scoresheetData.info.game_report}
          </Text>
        </View>
      </View>
    </Page>
  );
}

function FibaScoresheet({ scoresheetData }: FibaScoresheetProps) {
  const hasGameReport =
    scoresheetData.info.game_report &&
    scoresheetData.info.game_report.trim() !== '';

  const needsExtendedPage =
    scoresheetData.team_a.score > 160 || scoresheetData.team_b.score > 160;

  return (
    <Document title={`FIBA Scoresheet - Game ${scoresheetData.game_id}`}>
      <ScoresheetPage scoresheetData={scoresheetData} />
      {needsExtendedPage && (
        <ExtendedScoresheetPage scoresheetData={scoresheetData} />
      )}
      {hasGameReport && <GameReportPage scoresheetData={scoresheetData} />}
      <PointsSummaryPage scoresheetData={scoresheetData} />
    </Document>
  );
}

// Static method to parse data for this report type
export function parseFibaScoresheetData(rawData: string): FibaScoresheetData {
  try {
    return JSON.parse(rawData) as FibaScoresheetData;
  } catch (error) {
    throw new Error(`Invalid JSON data for FIBA scoresheet: ${error}`);
  }
}

export default FibaScoresheet;
