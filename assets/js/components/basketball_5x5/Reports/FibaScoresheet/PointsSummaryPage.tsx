import React from 'react';
import { useTranslation } from 'react-i18next';
import { Page, Text, View, StyleSheet } from '@react-pdf/renderer';
import {
  FibaScoresheetData,
  Team,
  Player,
  sumExtraTimeTotalScore,
} from '../FibaScoresheet';
import PageHeader from '../Shared/PageHeader';
import { textColorForPeriod, colorForPeriod, BLUE } from './styles';

const PERIODS = [1, 2, 3, 4];

const styles = StyleSheet.create({
  page: {
    flexDirection: 'column',
    backgroundColor: '#FFFFFF',
    padding: '12px',
    fontSize: 8,
  },
  tablesContainer: {
    flex: 1,
    display: 'flex',
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'center',
  },
  table: {
    width: '46%',
    margin: '0 2%',
    border: '1px solid #000',
    header: {
      padding: '4px',
      borderBottom: '1px solid #000',
      teamName: {
        fontSize: 10,
        fontWeight: 'bold',
        color: BLUE,
        textAlign: 'center',
      },
      teamLabel: {
        fontSize: 8,
        fontWeight: 'bold',
        textAlign: 'center',
        marginTop: '2px',
      },
      title: {
        fontSize: 8,
        fontWeight: 'bold',
        textAlign: 'center',
        marginTop: '2px',
      },
    },
    headRow: {
      display: 'flex',
      flexDirection: 'column',
      borderBottom: '1px solid #000',
      // No border-bearing columns here on purpose: this row only positions
      // the "Quarto" label over the four period columns below. Any rounding
      // drift in its own flex math is invisible (no vertical borders to
      // misalign) — the real column grid lives in columnsRow, which mirrors
      // `row`/`totalRow` cell-for-cell so widths match exactly everywhere.
      quarterLabelRow: {
        display: 'flex',
        flexDirection: 'row',
        numberSpacer: {
          flex: 1,
          borderBottom: '1px solid #000',
        },
        quarterLabel: {
          flex: 4,
          textAlign: 'center',
          borderBottom: '1px solid #000',
          padding: '1px',
        },
        extraSpacer: {
          flex: 1,
          borderBottom: '1px solid #000',
        },
        totalSpacer: {
          flex: 1,
          borderBottom: '1px solid #000',
        },
      },
      columnsRow: {
        display: 'flex',
        flexDirection: 'row',
        numberCell: {
          flex: 1,
          borderRight: '1px solid #000',
          display: 'flex',
          justifyContent: 'center',
          alignItems: 'center',
        },
        periodCell: {
          flex: 1,
          borderRight: '1px solid #000',
          display: 'flex',
          justifyContent: 'center',
          alignItems: 'center',
        },
        extraCell: {
          flex: 1,
          borderRight: '1px solid #000',
          display: 'flex',
          justifyContent: 'center',
          alignItems: 'center',
        },
        totalCell: {
          flex: 1,
          display: 'flex',
          justifyContent: 'center',
          alignItems: 'center',
        },
      },
    },
    row: {
      display: 'flex',
      flexDirection: 'row',
      borderBottom: '1px solid #000',
      height: '13px',
      numberCell: {
        flex: 1,
        borderRight: '1px solid #000',
        display: 'flex',
        justifyContent: 'center',
        alignItems: 'center',
      },
      periodCell: {
        flex: 1,
        borderRight: '1px solid #000',
        display: 'flex',
        justifyContent: 'center',
        alignItems: 'center',
        position: 'relative',
      },
      extraCell: {
        flex: 1,
        borderRight: '1px solid #000',
        display: 'flex',
        justifyContent: 'center',
        alignItems: 'center',
        position: 'relative',
      },
      totalCell: {
        flex: 1,
        display: 'flex',
        justifyContent: 'center',
        alignItems: 'center',
        position: 'relative',
      },
      unused: {
        position: 'absolute',
        top: '50%',
        left: '15%',
        width: '70%',
        height: '2px',
        borderTop: `2px solid ${BLUE}`,
      },
    },
    totalRow: {
      display: 'flex',
      flexDirection: 'row',
      minHeight: '15px',
      fontWeight: 'bold',
      label: {
        flex: 1,
        borderRight: '1px solid #000',
        display: 'flex',
        justifyContent: 'center',
        alignItems: 'center',
        fontSize: 6,
        textAlign: 'center',
      },
      periodCell: {
        flex: 1,
        borderRight: '1px solid #000',
        display: 'flex',
        justifyContent: 'center',
        alignItems: 'center',
      },
      extraCell: {
        flex: 1,
        borderRight: '1px solid #000',
        display: 'flex',
        justifyContent: 'center',
        alignItems: 'center',
        position: 'relative',
      },
      totalCell: {
        flex: 1,
        display: 'flex',
        justifyContent: 'center',
        alignItems: 'center',
      },
    },
  },
});

function UnusedCell({ color = BLUE }: { color?: string }) {
  return (
    <View
      style={{ ...styles.table.row.unused, borderTop: `2px solid ${color}` }}
    />
  );
}

function PeriodCell({
  period,
  points,
  isPeriodEnded,
  firstPlayedPeriod,
}: {
  period: number;
  points: number | undefined;
  isPeriodEnded: boolean;
  firstPlayedPeriod: number;
}) {
  const hasEnteredByPeriod = !!firstPlayedPeriod && firstPlayedPeriod <= period;

  return (
    <View style={styles.table.row.periodCell}>
      {points ? (
        <Text style={textColorForPeriod(period)}>{points}</Text>
      ) : hasEnteredByPeriod ? (
        isPeriodEnded && <Text style={textColorForPeriod(period)}>0</Text>
      ) : (
        isPeriodEnded && <UnusedCell color={colorForPeriod(period)} />
      )}
    </View>
  );
}

function PlayerRow({
  player,
  team,
  isGameEnded,
  endedPeriods,
  hasExtraPeriod,
}: {
  player: Player;
  team: Team;
  isGameEnded: boolean;
  endedPeriods: number[];
  hasExtraPeriod: boolean;
}) {
  const summary = team.points_summary?.[player.number];
  const didPlay = !!player.first_played_period || !!summary;

  return (
    <View style={styles.table.row}>
      <View style={styles.table.row.numberCell}>
        <Text>{player.number}</Text>
      </View>
      {PERIODS.map((period) => (
        <PeriodCell
          key={period}
          period={period}
          points={summary?.points_per_period?.[period]}
          isPeriodEnded={isGameEnded || endedPeriods.includes(period)}
          firstPlayedPeriod={player.first_played_period}
        />
      ))}
      <View style={styles.table.row.extraCell}>
        {!didPlay ? (
          isGameEnded && <UnusedCell />
        ) : summary?.extra ? (
          <Text>{summary.extra}</Text>
        ) : hasExtraPeriod ? (
          isGameEnded && <Text>0</Text>
        ) : (
          isGameEnded && <UnusedCell />
        )}
      </View>
      <View style={styles.table.row.totalCell}>
        {!didPlay ? (
          isGameEnded && <UnusedCell />
        ) : summary?.total ? (
          <Text>{summary.total}</Text>
        ) : (
          isGameEnded && <Text>0</Text>
        )}
      </View>
    </View>
  );
}

function PointsSummaryTable({
  type,
  team,
  isGameEnded,
  endedPeriods,
}: {
  type: 'A' | 'B';
  team: Team;
  isGameEnded: boolean;
  endedPeriods: number[];
}) {
  const { t } = useTranslation();
  const sortedPlayers = [...team.players].sort((a, b) => a.number - b.number);
  const extraTimeScore = sumExtraTimeTotalScore(team);
  const hasExtraPeriod = Object.keys(team.points_by_period).some(
    (period) => parseInt(period, 10) > 4,
  );

  return (
    <View style={styles.table}>
      <View style={styles.table.header}>
        <Text style={styles.table.header.teamName}>{team.name}</Text>
        <Text style={styles.table.header.teamLabel}>
          {`${t(
            'basketball.reports.fibaScoresheet.team',
          ).toUpperCase()} ${type}`}
        </Text>
        <Text style={styles.table.header.title}>
          {t('basketball.reports.fibaScoresheet.pointsSummary.title')}
        </Text>
      </View>
      <View style={styles.table.headRow}>
        <View style={styles.table.headRow.quarterLabelRow}>
          <View style={styles.table.headRow.quarterLabelRow.numberSpacer} />
          <Text style={styles.table.headRow.quarterLabelRow.quarterLabel}>
            {t('basketball.reports.fibaScoresheet.periods.quarter')}
          </Text>
          <View style={styles.table.headRow.quarterLabelRow.extraSpacer} />
          <View style={styles.table.headRow.quarterLabelRow.totalSpacer} />
        </View>
        <View style={styles.table.headRow.columnsRow}>
          <View style={styles.table.headRow.columnsRow.numberCell}>
            <Text>{t('basketball.reports.fibaScoresheet.number')}</Text>
          </View>
          {PERIODS.map((period) => (
            <View
              key={period}
              style={styles.table.headRow.columnsRow.periodCell}
            >
              <Text>{`${period}º`}</Text>
            </View>
          ))}
          <View style={styles.table.headRow.columnsRow.extraCell}>
            <Text>
              {t('basketball.reports.fibaScoresheet.pointsSummary.extra')}
            </Text>
          </View>
          <View style={styles.table.headRow.columnsRow.totalCell}>
            <Text>
              {t('basketball.reports.fibaScoresheet.pointsSummary.total')}
            </Text>
          </View>
        </View>
      </View>
      {sortedPlayers.map((player) => (
        <PlayerRow
          key={player.number}
          player={player}
          team={team}
          isGameEnded={isGameEnded}
          endedPeriods={endedPeriods}
          hasExtraPeriod={hasExtraPeriod}
        />
      ))}
      <View style={styles.table.totalRow}>
        <View style={styles.table.totalRow.label}>
          <Text>
            {t('basketball.reports.fibaScoresheet.pointsSummary.totalTeam')}
          </Text>
        </View>
        {PERIODS.map((period) => (
          <View key={period} style={styles.table.totalRow.periodCell}>
            <Text>{team.points_by_period?.[period] || 0}</Text>
          </View>
        ))}
        <View style={styles.table.totalRow.extraCell}>
          {hasExtraPeriod || !isGameEnded ? (
            <Text>{extraTimeScore}</Text>
          ) : (
            <UnusedCell />
          )}
        </View>
        <View style={styles.table.totalRow.totalCell}>
          <Text>{team.score}</Text>
        </View>
      </View>
    </View>
  );
}

interface PointsSummaryPageProps {
  scoresheetData: FibaScoresheetData;
}

function PointsSummaryPage({ scoresheetData }: PointsSummaryPageProps) {
  const isGameEnded = !!scoresheetData.info.actual_end_datetime;

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
      <View style={styles.tablesContainer}>
        <PointsSummaryTable
          type="A"
          team={scoresheetData.team_a}
          isGameEnded={isGameEnded}
          endedPeriods={scoresheetData.info.ended_periods || []}
        />
        <PointsSummaryTable
          type="B"
          team={scoresheetData.team_b}
          isGameEnded={isGameEnded}
          endedPeriods={scoresheetData.info.ended_periods || []}
        />
      </View>
    </Page>
  );
}

export default PointsSummaryPage;
