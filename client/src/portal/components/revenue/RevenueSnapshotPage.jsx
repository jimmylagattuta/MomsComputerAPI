import React, { useMemo, useState } from "react";
import RevenueBlankPageShell, {
  RevenuePlaceholderCard,
} from "./RevenueBlankPageShell";

const TARGET_SUBSCRIBERS = 2500;
const MONTHLY_PLAN_CENTS = 999;

export default function RevenueSnapshotPage({ kpis }) {
  const [activeFocusKey, setActiveFocusKey] = useState("subscriber_goal");
  const [activeRevenueWindowKey, setActiveRevenueWindowKey] = useState("month");

  const dateLabels = useMemo(() => {
    const now = new Date();

    const monthName = now.toLocaleDateString("en-US", {
      month: "long",
    });

    const yearNumber = now.getFullYear();

    return {
      month: {
        key: "month",
        eyebrow: "This Month",
        label: `${monthName} ${yearNumber}`,
        sublabel: "Current monthly revenue window",
        title: "Monthly Revenue",
        color: "#67e8f9",
      },
      year: {
        key: "year",
        eyebrow: "This Year",
        label: String(yearNumber),
        sublabel: "Year-to-date revenue window",
        title: "Yearly Revenue",
        color: "#fcd34d",
      },
      total: {
        key: "total",
        eyebrow: "All Time",
        label: "All Recorded Revenue",
        sublabel: "Total revenue since tracking began",
        title: "Total Revenue",
        color: "#c4b5fd",
      },
    };
  }, []);

  const snapshot = useMemo(() => {
    const mrrCents = pickNumber(
      kpis?.mrr_cents,
      kpis?.monthly_recurring_revenue_cents,
      kpis?.revenue_this_month_cents
    );

    const revenueThisMonthCents = pickNumber(
      kpis?.revenue_this_month_cents,
      kpis?.monthly_revenue_cents,
      kpis?.current_month_revenue_cents
    );

    const revenueThisYearCents = pickNumber(
      kpis?.revenue_this_year_cents,
      kpis?.yearly_revenue_cents,
      kpis?.current_year_revenue_cents
    );

    const totalRevenueCents = pickNumber(
      kpis?.total_revenue_cents,
      kpis?.lifetime_revenue_cents,
      kpis?.all_time_revenue_cents
    );

    const activeSubscribers = pickNumber(
      kpis?.active_subscribers,
      kpis?.paying_users,
      kpis?.subscribers
    );

    const billingIssueSubscribers = pickNumber(
      kpis?.billing_issue_subscribers,
      kpis?.billing_issues,
      kpis?.billing_issue_users
    );

    const cancelledSubscribers = pickNumber(
      kpis?.cancelled_subscribers,
      kpis?.cancelled_users,
      kpis?.canceled_subscribers
    );

    const expiredSubscribers = pickNumber(
      kpis?.expired_subscribers,
      kpis?.expired_users
    );

    const totalUsers = pickNumber(kpis?.total_users, kpis?.users_count);

    const targetMrrCents = TARGET_SUBSCRIBERS * MONTHLY_PLAN_CENTS;
    const targetYearlyRunRateCents = targetMrrCents * 12;

    const subscriberProgressPercent = clampPercent(
      (activeSubscribers / TARGET_SUBSCRIBERS) * 100
    );

    const mrrProgressPercent = clampPercent((mrrCents / targetMrrCents) * 100);

    const subscribersRemaining = Math.max(
      TARGET_SUBSCRIBERS - activeSubscribers,
      0
    );

    const mrrGapCents = Math.max(targetMrrCents - mrrCents, 0);

    const currentYearlyRunRateCents = mrrCents * 12;

    const averageRevenuePerUserCents =
      activeSubscribers > 0
        ? Math.round(totalRevenueCents / activeSubscribers)
        : 0;

    const paymentRiskCount =
      billingIssueSubscribers + cancelledSubscribers + expiredSubscribers;

    const healthySubscriberPercent = clampPercent(
      activeSubscribers + paymentRiskCount > 0
        ? (activeSubscribers / (activeSubscribers + paymentRiskCount)) * 100
        : 0
    );

    const userToSubscriberPercent = clampPercent(
      totalUsers > 0 ? (activeSubscribers / totalUsers) * 100 : 0
    );

    const revenueWindows = [
      {
        ...dateLabels.month,
        valueCents: revenueThisMonthCents,
        compareLabel: "Current MRR",
        compareValueCents: mrrCents,
        description:
          "Actual successful subscription revenue collected during the current month.",
        detail:
          revenueThisMonthCents > 0
            ? `${formatMoneyFromCents(
                revenueThisMonthCents
              )} has been collected so far this month.`
            : "No successful subscription revenue is recorded for the current month yet.",
      },
      {
        ...dateLabels.year,
        valueCents: revenueThisYearCents,
        compareLabel: "Annualized Run-Rate",
        compareValueCents: currentYearlyRunRateCents,
        description:
          "Successful subscription revenue collected during the current calendar year.",
        detail:
          revenueThisYearCents > 0
            ? `${formatMoneyFromCents(
                revenueThisYearCents
              )} has been collected so far this year.`
            : "No successful subscription revenue is recorded for the current year yet.",
      },
      {
        ...dateLabels.total,
        valueCents: totalRevenueCents,
        compareLabel: "Average Revenue / Paying User",
        compareValueCents: averageRevenuePerUserCents,
        description:
          "All successful subscription revenue recorded in the system.",
        detail:
          totalRevenueCents > 0
            ? `${formatMoneyFromCents(
                totalRevenueCents
              )} has been recorded across all successful subscription transactions.`
            : "No successful subscription revenue has been recorded yet.",
      },
    ];

    return {
      mrrCents,
      revenueThisMonthCents,
      revenueThisYearCents,
      totalRevenueCents,
      activeSubscribers,
      billingIssueSubscribers,
      cancelledSubscribers,
      expiredSubscribers,
      totalUsers,
      averageRevenuePerUserCents,
      paymentRiskCount,
      targetMrrCents,
      targetYearlyRunRateCents,
      subscriberProgressPercent,
      mrrProgressPercent,
      subscribersRemaining,
      mrrGapCents,
      currentYearlyRunRateCents,
      healthySubscriberPercent,
      userToSubscriberPercent,
      revenueWindows,
    };
  }, [kpis, dateLabels]);

  const activeRevenueWindow =
    snapshot.revenueWindows.find(
      (window) => window.key === activeRevenueWindowKey
    ) || snapshot.revenueWindows[0];

  const focusItems = [
    {
      key: "subscriber_goal",
      eyebrow: "Main Goal",
      title: "2,500 Subscriber Target",
      value: `${formatNumber(snapshot.activeSubscribers)} / ${formatNumber(
        TARGET_SUBSCRIBERS
      )}`,
      color: "#67e8f9",
      percent: snapshot.subscriberProgressPercent,
      summary:
        "This shows how close the app is to the 2,500 paying subscriber goal.",
      detail: `${formatNumber(
        snapshot.subscribersRemaining
      )} more paying subscribers are needed to reach the 2,500 subscriber goal.`,
      question: "How close is the app to the subscriber target?",
      donutLabel: "Goal Progress",
    },
    {
      key: "mrr_goal",
      eyebrow: "Monthly Money Goal",
      title: "MRR at 2,500 Subscribers",
      value: formatMoneyFromCents(snapshot.targetMrrCents),
      color: "#86efac",
      percent: snapshot.mrrProgressPercent,
      summary:
        "At $9.99/month, 2,500 subscribers equals about $24,975 in monthly recurring revenue.",
      detail: `Current MRR is ${formatMoneyFromCents(
        snapshot.mrrCents
      )}. The remaining monthly gap is ${formatMoneyFromCents(
        snapshot.mrrGapCents
      )}.`,
      question: "What does 2,500 subscribers mean in monthly revenue?",
      donutLabel: "MRR Progress",
    },
    {
      key: "yearly_run_rate",
      eyebrow: "Annualized Value",
      title: "Yearly Run Rate at Goal",
      value: formatMoneyFromCents(snapshot.targetYearlyRunRateCents),
      color: "#fcd34d",
      percent: snapshot.mrrProgressPercent,
      summary:
        "This shows the yearly run-rate if the app reaches 2,500 paying subscribers.",
      detail: `Current annualized run-rate is ${formatMoneyFromCents(
        snapshot.currentYearlyRunRateCents
      )}. At goal, the run-rate becomes ${formatMoneyFromCents(
        snapshot.targetYearlyRunRateCents
      )}.`,
      question: "What does the goal look like annually?",
      donutLabel: "Run-Rate Progress",
    },
    {
      key: "conversion",
      eyebrow: "User Base",
      title: "Users Converted to Paying",
      value: formatPercent(snapshot.userToSubscriberPercent, 1),
      color: "#c4b5fd",
      percent: snapshot.userToSubscriberPercent,
      summary:
        "This shows how much of the registered user base is currently paying.",
      detail: `${formatNumber(
        snapshot.activeSubscribers
      )} active paying users out of ${formatNumber(
        snapshot.totalUsers
      )} total registered users.`,
      question: "Are registered users turning into paying customers?",
      donutLabel: "Conversion",
    },
    {
      key: "subscription_health",
      eyebrow: "Revenue Protection",
      title: "Healthy Subscriber Base",
      value: formatPercent(snapshot.healthySubscriberPercent, 1),
      color: "#93c5fd",
      percent: snapshot.healthySubscriberPercent,
      summary:
        "This shows how much of the subscription base is healthy compared with accounts that may reduce future revenue.",
      detail: `${formatNumber(
        snapshot.activeSubscribers
      )} paying normally. ${formatNumber(
        snapshot.paymentRiskCount
      )} accounts are billing issue, cancelled, or expired.`,
      question: "How much revenue is safe versus at risk?",
      donutLabel: "Healthy Base",
    },
  ];

  const activeFocus =
    focusItems.find((item) => item.key === activeFocusKey) || focusItems[0];

  const subscriberHealthData = [
    {
      key: "active",
      label: "Paying Normally",
      value: snapshot.activeSubscribers,
      color: "#86efac",
      description:
        "Healthy paying customers. This group is producing recurring revenue.",
    },
    {
      key: "billing",
      label: "Payment Issue",
      value: snapshot.billingIssueSubscribers,
      color: "#fde68a",
      description:
        "Users whose payment may have failed or whose renewal needs attention.",
    },
    {
      key: "cancelled",
      label: "Cancelled",
      value: snapshot.cancelledSubscribers,
      color: "#fb7185",
      description:
        "Users who cancelled. They may still have access until the billing period ends.",
    },
    {
      key: "expired",
      label: "Access Ended",
      value: snapshot.expiredSubscribers,
      color: "#fca5a5",
      description: "Users whose paid subscription access has ended.",
    },
  ];

  return (
    <div style={{ display: "grid", gap: 22 }}>
      <RevenueBlankPageShell
        emoji="📊"
        title="Revenue Snapshot"
        subtitle="A command center focused on the 2,500 subscriber goal, monthly revenue potential, and subscription health."
      >
        <RevenuePlaceholderCard
          label="Current Paying Subscribers"
          value={formatNumber(snapshot.activeSubscribers)}
          subtext={`Goal: ${formatNumber(TARGET_SUBSCRIBERS)} paying subscribers.`}
          color="#67e8f9"
        />

        <RevenuePlaceholderCard
          label="Subscribers Remaining"
          value={formatNumber(snapshot.subscribersRemaining)}
          subtext="How many more paying users are needed to reach the goal."
          color="#fcd34d"
        />

        <RevenuePlaceholderCard
          label="Current Monthly Run-Rate"
          value={formatMoneyFromCents(snapshot.mrrCents)}
          subtext="Expected monthly subscription income from current active subscribers."
          color="#86efac"
        />

        <RevenuePlaceholderCard
          label="Monthly Revenue at Goal"
          value={formatMoneyFromCents(snapshot.targetMrrCents)}
          subtext={`At ${formatMoneyFromCents(
            MONTHLY_PLAN_CENTS
          )}/month × ${formatNumber(TARGET_SUBSCRIBERS)} subscribers.`}
          color="#c4b5fd"
        />

        <RevenuePlaceholderCard
          label="Yearly Run-Rate at Goal"
          value={formatMoneyFromCents(snapshot.targetYearlyRunRateCents)}
          subtext="Annualized subscription revenue if the 2,500 subscriber goal is reached."
          color="#93c5fd"
        />

        <RevenuePlaceholderCard
          label="Monthly Gap to Goal"
          value={formatMoneyFromCents(snapshot.mrrGapCents)}
          subtext="Additional monthly recurring revenue needed to reach the goal."
          color="#fb7185"
        />

        <RevenuePlaceholderCard
          label="Collected This Month"
          value={formatMoneyFromCents(snapshot.revenueThisMonthCents)}
          subtext="Actual successful subscription payments collected this month."
          color="#86efac"
        />

        <RevenuePlaceholderCard
          label="Collected This Year"
          value={formatMoneyFromCents(snapshot.revenueThisYearCents)}
          subtext="Year-to-date revenue for accounting and tax review."
          color="#fcd34d"
        />

        <RevenuePlaceholderCard
          label="Total Collected"
          value={formatMoneyFromCents(snapshot.totalRevenueCents)}
          subtext="All successful subscription revenue recorded so far."
          color="#c4b5fd"
        />

        <RevenuePlaceholderCard
          label="Revenue Risk Accounts"
          value={formatNumber(snapshot.paymentRiskCount)}
          subtext="Billing issue, cancelled, and expired accounts combined."
          color="#fca5a5"
        />

        <RevenuePlaceholderCard
          label="Total Registered Users"
          value={formatNumber(snapshot.totalUsers)}
          subtext="All users in the system, including free, inactive, trial, and paid."
          color="#ffffff"
        />

        <RevenuePlaceholderCard
          label="Average Revenue / Paying User"
          value={formatMoneyFromCents(snapshot.averageRevenuePerUserCents)}
          subtext="Total recorded revenue divided by active paying subscribers."
          color="#93c5fd"
        />
      </RevenueBlankPageShell>

      <RevenueWindowBanner activeWindow={activeRevenueWindow} />

      <RevenueWindowTabs
        windows={snapshot.revenueWindows}
        activeWindowKey={activeRevenueWindowKey}
        onSelectWindow={setActiveRevenueWindowKey}
      />

      <section
        className="revenue-snapshot-two-column"
        style={{
          display: "grid",
          gridTemplateColumns: "minmax(0, 1.2fr) minmax(320px, 0.8fr)",
          gap: 18,
        }}
      >
        <RevenueWindowBoard activeWindow={activeRevenueWindow} />

        <RevenueWindowInspector activeWindow={activeRevenueWindow} />
      </section>

      <section
        className="revenue-snapshot-two-column"
        style={{
          display: "grid",
          gridTemplateColumns: "minmax(0, 1.2fr) minmax(320px, 0.8fr)",
          gap: 18,
        }}
      >
        <GoalProgressBoard
          focusItems={focusItems}
          activeFocusKey={activeFocusKey}
          onSelectFocus={setActiveFocusKey}
        />

        <GoalInspector focus={activeFocus} />
      </section>

      <section
        className="revenue-snapshot-two-column"
        style={{
          display: "grid",
          gridTemplateColumns: "minmax(0, 1.2fr) minmax(320px, 0.8fr)",
          gap: 18,
        }}
      >
        <SubscriberGoalLadder
          activeSubscribers={snapshot.activeSubscribers}
          currentMrrCents={snapshot.mrrCents}
          onSelectFocus={setActiveFocusKey}
        />

        <SubscriberHealthPanel
          data={subscriberHealthData}
          snapshot={snapshot}
          onSelectFocus={setActiveFocusKey}
        />
      </section>

      <style>
        {`
          .goal-progress-row:hover,
          .goal-ladder-card:hover,
          .subscriber-health-row:hover,
          .revenue-window-button:hover {
            transform: translateY(-3px);
            box-shadow: 0 18px 38px rgba(0,0,0,0.28) !important;
          }

          .goal-progress-row:active,
          .goal-ladder-card:active,
          .subscriber-health-row:active,
          .revenue-window-button:active {
            transform: translateY(-1px);
          }

          .goal-progress-row:focus-visible,
          .goal-ladder-card:focus-visible,
          .subscriber-health-row:focus-visible,
          .revenue-window-button:focus-visible {
            outline: 2px solid rgba(147,197,253,0.72);
            outline-offset: 4px;
          }

          @media (max-width: 940px) {
            .revenue-snapshot-two-column {
              grid-template-columns: 1fr !important;
            }
          }
        `}
      </style>
    </div>
  );
}

function RevenueWindowBanner({ activeWindow }) {
  return (
    <section
      style={{
        borderRadius: 28,
        padding: "24px 26px",
        background:
          "radial-gradient(circle at top left, rgba(34,211,238,0.18), transparent 28%), radial-gradient(circle at top right, rgba(168,85,247,0.16), transparent 32%), linear-gradient(135deg, rgba(15,23,42,0.96), rgba(30,41,59,0.72))",
        border: `1px solid ${hexToRgba(activeWindow.color, 0.25)}`,
        boxShadow: "0 22px 54px rgba(0,0,0,0.26)",
        overflow: "hidden",
        position: "relative",
      }}
    >
      <div
        style={{
          position: "absolute",
          right: -40,
          top: -54,
          width: 190,
          height: 190,
          borderRadius: "50%",
          background: hexToRgba(activeWindow.color, 0.1),
          filter: "blur(2px)",
          pointerEvents: "none",
        }}
      />

      <div
        style={{
          display: "flex",
          justifyContent: "space-between",
          gap: 18,
          alignItems: "center",
          flexWrap: "wrap",
          position: "relative",
          zIndex: 2,
        }}
      >
        <div>
          <div
            style={{
              color: activeWindow.color,
              fontSize: "0.78rem",
              fontWeight: 950,
              textTransform: "uppercase",
              letterSpacing: "0.1em",
            }}
          >
            {activeWindow.eyebrow}
          </div>

          <div
            style={{
              marginTop: 8,
              color: "#ffffff",
              fontSize: "clamp(2rem, 5vw, 4.2rem)",
              fontWeight: 950,
              letterSpacing: "-0.08em",
              lineHeight: 0.95,
              textShadow: "0 18px 42px rgba(0,0,0,0.35)",
            }}
          >
            {activeWindow.label}
          </div>

          <div
            style={{
              marginTop: 10,
              color: "#cbd5e1",
              fontSize: "0.98rem",
              fontWeight: 750,
            }}
          >
            {activeWindow.sublabel}
          </div>
        </div>

        <div
          style={{
            minWidth: 240,
            borderRadius: 24,
            padding: 18,
            background: "rgba(255,255,255,0.045)",
            border: "1px solid rgba(255,255,255,0.10)",
            boxShadow: "inset 0 1px 0 rgba(255,255,255,0.05)",
          }}
        >
          <div
            style={{
              color: "#94a3b8",
              fontSize: "0.74rem",
              fontWeight: 950,
              textTransform: "uppercase",
              letterSpacing: "0.08em",
            }}
          >
            Selected Revenue Window
          </div>

          <div
            style={{
              marginTop: 8,
              color: activeWindow.color,
              fontSize: "1.85rem",
              fontWeight: 950,
              letterSpacing: "-0.06em",
            }}
          >
            {formatMoneyFromCents(activeWindow.valueCents)}
          </div>

          <div
            style={{
              marginTop: 8,
              color: "#cbd5e1",
              fontSize: "0.85rem",
              fontWeight: 850,
            }}
          >
            {activeWindow.title}
          </div>
        </div>
      </div>
    </section>
  );
}

function RevenueWindowTabs({ windows, activeWindowKey, onSelectWindow }) {
  return (
    <section style={graphCardStyle}>
      <GraphHeader
        eyebrow="Revenue Windows"
        title="Monthly, Yearly, and Total Revenue"
        subtitle="Switch between the current month, current year, and all recorded revenue."
      />

      <div
        style={{
          display: "grid",
          gridTemplateColumns: "repeat(auto-fit, minmax(220px, 1fr))",
          gap: 12,
          marginTop: 18,
        }}
      >
        {windows.map((window) => {
          const isActive = activeWindowKey === window.key;

          return (
            <button
              key={window.key}
              type="button"
              onClick={() => onSelectWindow(window.key)}
              className="revenue-window-button"
              style={{
                borderRadius: 20,
                padding: 16,
                border: isActive
                  ? `1px solid ${hexToRgba(window.color, 0.45)}`
                  : "1px solid rgba(255,255,255,0.08)",
                background: isActive
                  ? `linear-gradient(135deg, ${hexToRgba(
                      window.color,
                      0.16
                    )}, rgba(168,85,247,0.10))`
                  : "rgba(255,255,255,0.035)",
                color: "#ffffff",
                textAlign: "left",
                cursor: "pointer",
                transition:
                  "transform 0.18s ease, border-color 0.18s ease, background 0.18s ease, box-shadow 0.18s ease",
              }}
            >
              <div
                style={{
                  color: window.color,
                  fontSize: "0.72rem",
                  fontWeight: 950,
                  textTransform: "uppercase",
                  letterSpacing: "0.08em",
                }}
              >
                {window.eyebrow}
              </div>

              <div
                style={{
                  marginTop: 6,
                  color: "#ffffff",
                  fontSize: "1.05rem",
                  fontWeight: 950,
                }}
              >
                {window.label}
              </div>

              <div
                style={{
                  marginTop: 10,
                  color: isActive ? window.color : "#cbd5e1",
                  fontSize: "1.55rem",
                  fontWeight: 950,
                  letterSpacing: "-0.05em",
                }}
              >
                {formatMoneyFromCents(window.valueCents)}
              </div>

              <div
                style={{
                  marginTop: 7,
                  color: "#94a3b8",
                  fontSize: "0.82rem",
                  lineHeight: 1.45,
                  fontWeight: 750,
                }}
              >
                {window.description}
              </div>
            </button>
          );
        })}
      </div>
    </section>
  );
}

function RevenueWindowBoard({ activeWindow }) {
  return (
    <section style={graphCardStyle}>
      <GraphHeader
        eyebrow={activeWindow.eyebrow}
        title={activeWindow.title}
        subtitle={activeWindow.description}
      />

      <div
        style={{
          marginTop: 20,
          borderRadius: 24,
          padding: 22,
          background: "rgba(255,255,255,0.045)",
          border: `1px solid ${hexToRgba(activeWindow.color, 0.24)}`,
        }}
      >
        <div
          style={{
            color: "#94a3b8",
            fontSize: "0.78rem",
            fontWeight: 950,
            textTransform: "uppercase",
            letterSpacing: "0.08em",
          }}
        >
          {activeWindow.label}
        </div>

        <div
          style={{
            marginTop: 8,
            color: activeWindow.color,
            fontSize: "clamp(2rem, 5vw, 3.25rem)",
            fontWeight: 950,
            letterSpacing: "-0.07em",
            lineHeight: 1,
          }}
        >
          {formatMoneyFromCents(activeWindow.valueCents)}
        </div>

        <p
          style={{
            margin: "14px 0 0",
            color: "#e2e8f0",
            fontSize: "0.96rem",
            lineHeight: 1.65,
            fontWeight: 750,
          }}
        >
          {activeWindow.detail}
        </p>
      </div>
    </section>
  );
}

function RevenueWindowInspector({ activeWindow }) {
  return (
    <section
      style={{
        ...graphCardStyle,
        background: `radial-gradient(circle at top right, ${hexToRgba(
          activeWindow.color,
          0.18
        )}, transparent 36%), rgba(15,23,42,0.82)`,
      }}
    >
      <GraphHeader
        eyebrow="Selected Window"
        title={activeWindow.label}
        subtitle={activeWindow.sublabel}
      />

      <div
        style={{
          display: "grid",
          gridTemplateColumns: "repeat(2, minmax(0, 1fr))",
          gap: 12,
          marginTop: 18,
        }}
      >
        <MiniStat
          label="Revenue"
          value={formatMoneyFromCents(activeWindow.valueCents)}
          color={activeWindow.color}
        />

        <MiniStat
          label={activeWindow.compareLabel}
          value={formatMoneyFromCents(activeWindow.compareValueCents)}
          color="#93c5fd"
        />
      </div>

      <InfoBox
        label="What this means"
        value={activeWindow.detail}
        color={activeWindow.color}
      />
    </section>
  );
}

function GoalProgressBoard({ focusItems, activeFocusKey, onSelectFocus }) {
  return (
    <section style={graphCardStyle}>
      <GraphHeader
        eyebrow="Goal Progress"
        title="Path to 2,500 Subscribers"
        subtitle="These bars show progress toward the actual subscriber and revenue goals."
      />

      <div style={{ display: "grid", gap: 14, marginTop: 18 }}>
        {focusItems.map((item) => {
          const isActive = activeFocusKey === item.key;
          const percent = clampPercent(item.percent);

          return (
            <button
              key={item.key}
              type="button"
              onMouseEnter={() => onSelectFocus(item.key)}
              onFocus={() => onSelectFocus(item.key)}
              onClick={() => onSelectFocus(item.key)}
              className="goal-progress-row"
              style={{
                border: isActive
                  ? `1px solid ${hexToRgba(item.color, 0.58)}`
                  : "1px solid rgba(255,255,255,0.08)",
                background: isActive
                  ? hexToRgba(item.color, 0.11)
                  : "rgba(255,255,255,0.035)",
                borderRadius: 18,
                padding: 15,
                cursor: "pointer",
                textAlign: "left",
                transition:
                  "transform 0.18s ease, border-color 0.18s ease, background 0.18s ease, box-shadow 0.18s ease",
              }}
            >
              <div
                style={{
                  display: "flex",
                  justifyContent: "space-between",
                  gap: 12,
                  alignItems: "baseline",
                  marginBottom: 10,
                }}
              >
                <div>
                  <div
                    style={{
                      color: item.color,
                      fontSize: "0.72rem",
                      fontWeight: 950,
                      textTransform: "uppercase",
                      letterSpacing: "0.08em",
                    }}
                  >
                    {item.eyebrow}
                  </div>

                  <div
                    style={{
                      color: "#ffffff",
                      fontWeight: 950,
                      fontSize: "0.98rem",
                      marginTop: 4,
                    }}
                  >
                    {item.title}
                  </div>
                </div>

                <div
                  style={{
                    color: item.color,
                    fontWeight: 950,
                    fontSize: "1.05rem",
                    whiteSpace: "nowrap",
                  }}
                >
                  {item.value}
                </div>
              </div>

              <div
                style={{
                  height: 15,
                  borderRadius: 999,
                  background: "rgba(255,255,255,0.06)",
                  border: "1px solid rgba(255,255,255,0.06)",
                  overflow: "hidden",
                }}
              >
                <div
                  style={{
                    width: `${Math.max(percent, 0.8)}%`,
                    height: "100%",
                    borderRadius: 999,
                    background: `linear-gradient(90deg, ${hexToRgba(
                      item.color,
                      0.35
                    )}, ${item.color})`,
                    boxShadow: `0 0 24px ${hexToRgba(item.color, 0.28)}`,
                    transition: "width 0.35s ease",
                  }}
                />
              </div>

              <div
                style={{
                  marginTop: 8,
                  color: "#94a3b8",
                  fontSize: "0.8rem",
                  fontWeight: 800,
                }}
              >
                {formatPercent(percent, 1)} complete
              </div>
            </button>
          );
        })}
      </div>
    </section>
  );
}

function GoalInspector({ focus }) {
  return (
    <section
      style={{
        ...graphCardStyle,
        background: `radial-gradient(circle at top right, ${hexToRgba(
          focus.color,
          0.18
        )}, transparent 36%), rgba(15,23,42,0.82)`,
        display: "grid",
        alignContent: "start",
        gap: 18,
        overflow: "visible",
      }}
    >
      <GraphHeader
        eyebrow={focus.eyebrow}
        title={focus.title}
        subtitle={focus.question}
      />

      <div
        style={{
          borderRadius: 24,
          padding: 22,
          background: "rgba(255,255,255,0.045)",
          border: `1px solid ${hexToRgba(focus.color, 0.24)}`,
          minWidth: 0,
        }}
      >
        <div
          style={{
            color: "#94a3b8",
            fontSize: "0.78rem",
            fontWeight: 950,
            textTransform: "uppercase",
            letterSpacing: "0.08em",
          }}
        >
          Current Answer
        </div>

        <div
          style={{
            marginTop: 8,
            color: focus.color,
            fontSize: "clamp(1.8rem, 4vw, 2.6rem)",
            fontWeight: 950,
            letterSpacing: "-0.07em",
            lineHeight: 1,
          }}
        >
          {focus.value}
        </div>

        <p
          style={{
            margin: "14px 0 0",
            color: "#e2e8f0",
            fontSize: "0.96rem",
            lineHeight: 1.65,
            fontWeight: 750,
          }}
        >
          {focus.summary}
        </p>
      </div>

      <div
        style={{
          display: "grid",
          placeItems: "center",
          paddingTop: 10,
          paddingBottom: 10,
          overflow: "visible",
        }}
      >
        <ProgressDonut
          percent={focus.percent}
          color={focus.color}
          label={focus.donutLabel}
          size={240}
          innerSize={148}
        />
      </div>

      <InfoBox
        label="What this means"
        value={focus.detail}
        color={focus.color}
      />
    </section>
  );
}

function ProgressDonut({ percent, color, label, size = 160, innerSize = 104 }) {
  const safePercent = clampPercent(percent);
  const strokeWidth = Math.max(16, Math.round(size * 0.12));
  const radius = (size - strokeWidth) / 2;
  const circumference = 2 * Math.PI * radius;
  const dashOffset = circumference * (1 - safePercent / 100);
  const center = size / 2;
  const useRoundCap = safePercent > 0 && safePercent < 100 && safePercent >= 1;

  return (
    <div
      style={{
        display: "grid",
        placeItems: "center",
        padding: 16,
        overflow: "visible",
      }}
    >
      <div
        style={{
          position: "relative",
          width: size + 28,
          height: size + 28,
          display: "grid",
          placeItems: "center",
          overflow: "visible",
        }}
      >
        <svg
          width={size}
          height={size}
          viewBox={`0 0 ${size} ${size}`}
          style={{
            overflow: "visible",
            filter: `drop-shadow(0 0 24px ${hexToRgba(color, 0.16)})`,
          }}
        >
          <circle
            cx={center}
            cy={center}
            r={radius}
            fill="none"
            stroke="rgba(255,255,255,0.08)"
            strokeWidth={strokeWidth}
          />

          <circle
            cx={center}
            cy={center}
            r={radius}
            fill="none"
            stroke={color}
            strokeWidth={strokeWidth}
            strokeDasharray={circumference}
            strokeDashoffset={dashOffset}
            strokeLinecap={useRoundCap ? "round" : "butt"}
            transform={`rotate(-90 ${center} ${center})`}
            style={{
              transition:
                "stroke-dashoffset 0.35s ease, stroke 0.25s ease, filter 0.25s ease",
            }}
          />
        </svg>

        <div
          style={{
            position: "absolute",
            width: innerSize,
            height: innerSize,
            borderRadius: "50%",
            background: "rgba(15,23,42,0.96)",
            border: "1px solid rgba(255,255,255,0.10)",
            display: "grid",
            placeItems: "center",
            textAlign: "center",
            padding: 12,
            boxShadow: "inset 0 0 0 1px rgba(255,255,255,0.03)",
          }}
        >
          <div>
            <div
              style={{
                color: "#94a3b8",
                fontSize: "0.68rem",
                fontWeight: 950,
                textTransform: "uppercase",
                letterSpacing: "0.08em",
              }}
            >
              {label}
            </div>

            <div
              style={{
                color,
                fontSize: size >= 220 ? "2.5rem" : "2rem",
                fontWeight: 950,
                letterSpacing: "-0.07em",
                lineHeight: 1,
                marginTop: 6,
              }}
            >
              {formatPercent(safePercent, 1)}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

function SubscriberGoalLadder({
  activeSubscribers,
  currentMrrCents,
  onSelectFocus,
}) {
  const milestones = [100, 250, 500, 1000, 1500, 2000, 2500];

  return (
    <section style={graphCardStyle}>
      <GraphHeader
        eyebrow="Milestones"
        title="Subscriber Goal Ladder"
        subtitle="Each step shows the monthly revenue connected to a subscriber milestone."
      />

      <div
        style={{
          display: "grid",
          gridTemplateColumns: "repeat(auto-fit, minmax(150px, 1fr))",
          gap: 12,
          marginTop: 18,
        }}
      >
        {milestones.map((milestone) => {
          const milestoneMrrCents = milestone * MONTHLY_PLAN_CENTS;
          const reached = activeSubscribers >= milestone;
          const currentMilestoneProgress = clampPercent(
            (activeSubscribers / milestone) * 100
          );

          return (
            <button
              key={milestone}
              type="button"
              onMouseEnter={() => onSelectFocus("subscriber_goal")}
              onFocus={() => onSelectFocus("subscriber_goal")}
              onClick={() => onSelectFocus("subscriber_goal")}
              className="goal-ladder-card"
              style={{
                minHeight: 150,
                borderRadius: 22,
                padding: 16,
                background: reached
                  ? "linear-gradient(135deg, rgba(34,197,94,0.16), rgba(255,255,255,0.035))"
                  : "rgba(255,255,255,0.035)",
                border: reached
                  ? "1px solid rgba(134,239,172,0.32)"
                  : "1px solid rgba(255,255,255,0.08)",
                color: "#ffffff",
                cursor: "pointer",
                textAlign: "left",
                display: "grid",
                alignContent: "space-between",
                gap: 14,
                transition:
                  "transform 0.18s ease, border-color 0.18s ease, background 0.18s ease, box-shadow 0.18s ease",
              }}
            >
              <div>
                <div
                  style={{
                    color: reached ? "#86efac" : "#94a3b8",
                    fontSize: "0.72rem",
                    fontWeight: 950,
                    textTransform: "uppercase",
                    letterSpacing: "0.08em",
                  }}
                >
                  {reached ? "Reached" : "Target"}
                </div>

                <div
                  style={{
                    marginTop: 6,
                    color: reached ? "#86efac" : "#ffffff",
                    fontSize: "1.7rem",
                    fontWeight: 950,
                    letterSpacing: "-0.05em",
                  }}
                >
                  {formatNumber(milestone)}
                </div>

                <div
                  style={{
                    color: "#cbd5e1",
                    fontSize: "0.8rem",
                    fontWeight: 800,
                  }}
                >
                  subscribers
                </div>
              </div>

              <div>
                <div
                  style={{
                    color: "#93c5fd",
                    fontSize: "0.9rem",
                    fontWeight: 950,
                    marginBottom: 8,
                  }}
                >
                  {formatMoneyFromCents(milestoneMrrCents)}/mo
                </div>

                <div
                  style={{
                    height: 9,
                    borderRadius: 999,
                    background: "rgba(255,255,255,0.07)",
                    overflow: "hidden",
                  }}
                >
                  <div
                    style={{
                      width: `${Math.max(currentMilestoneProgress, 0.8)}%`,
                      height: "100%",
                      borderRadius: 999,
                      background: reached ? "#86efac" : "#67e8f9",
                    }}
                  />
                </div>

                <div
                  style={{
                    marginTop: 7,
                    color: "#94a3b8",
                    fontSize: "0.74rem",
                    fontWeight: 800,
                  }}
                >
                  {formatPercent(currentMilestoneProgress, 1)} complete
                </div>
              </div>
            </button>
          );
        })}
      </div>

      <div
        style={{
          marginTop: 18,
          padding: 16,
          borderRadius: 18,
          background: "rgba(255,255,255,0.035)",
          border: "1px solid rgba(255,255,255,0.08)",
        }}
      >
        <div
          style={{
            color: "#ffffff",
            fontSize: "0.95rem",
            fontWeight: 950,
            marginBottom: 8,
          }}
        >
          Current run-rate
        </div>

        <p
          style={{
            margin: 0,
            color: "#cbd5e1",
            fontSize: "0.9rem",
            lineHeight: 1.6,
          }}
        >
          Current active subscribers generate an estimated{" "}
          <strong style={{ color: "#86efac" }}>
            {formatMoneyFromCents(currentMrrCents)}/month
          </strong>
          . The 2,500 subscriber goal would generate{" "}
          <strong style={{ color: "#93c5fd" }}>
            {formatMoneyFromCents(TARGET_SUBSCRIBERS * MONTHLY_PLAN_CENTS)}
            /month
          </strong>
          .
        </p>
      </div>
    </section>
  );
}

function SubscriberHealthPanel({ data, snapshot, onSelectFocus }) {
  const totalHealth = Math.max(
    snapshot.activeSubscribers + snapshot.paymentRiskCount,
    1
  );

  return (
    <section style={graphCardStyle}>
      <GraphHeader
        eyebrow="Revenue Protection"
        title="Subscriber Health"
        subtitle="This shows whether paid customers are healthy or at risk."
      />

      <div style={{ marginTop: 18, display: "grid", gap: 10 }}>
        {data.map((item) => {
          const percent = clampPercent((item.value / totalHealth) * 100);

          return (
            <button
              key={item.key}
              type="button"
              onMouseEnter={() => onSelectFocus("subscription_health")}
              onFocus={() => onSelectFocus("subscription_health")}
              onClick={() => onSelectFocus("subscription_health")}
              className="subscriber-health-row"
              style={{
                display: "grid",
                gap: 9,
                padding: 13,
                borderRadius: 16,
                background: "rgba(255,255,255,0.035)",
                border: `1px solid ${hexToRgba(item.color, 0.18)}`,
                color: "#ffffff",
                cursor: "pointer",
                textAlign: "left",
                transition:
                  "transform 0.18s ease, border-color 0.18s ease, background 0.18s ease, box-shadow 0.18s ease",
              }}
            >
              <div
                style={{
                  display: "flex",
                  justifyContent: "space-between",
                  alignItems: "center",
                  gap: 12,
                }}
              >
                <span
                  style={{
                    display: "flex",
                    alignItems: "center",
                    gap: 9,
                    fontWeight: 900,
                  }}
                >
                  <span
                    style={{
                      width: 10,
                      height: 10,
                      borderRadius: "50%",
                      background: item.color,
                      boxShadow: `0 0 14px ${hexToRgba(item.color, 0.42)}`,
                    }}
                  />
                  {item.label}
                </span>

                <span
                  style={{
                    color: item.color,
                    fontWeight: 950,
                  }}
                >
                  {formatNumber(item.value)}
                </span>
              </div>

              <div
                style={{
                  height: 9,
                  borderRadius: 999,
                  background: "rgba(255,255,255,0.07)",
                  overflow: "hidden",
                }}
              >
                <div
                  style={{
                    width: `${Math.max(percent, item.value > 0 ? 4 : 1)}%`,
                    height: "100%",
                    borderRadius: 999,
                    background: item.color,
                    boxShadow: `0 0 18px ${hexToRgba(item.color, 0.32)}`,
                  }}
                />
              </div>

              <div
                style={{
                  color: "#94a3b8",
                  fontSize: "0.8rem",
                  lineHeight: 1.45,
                  fontWeight: 700,
                }}
              >
                {item.description}
              </div>
            </button>
          );
        })}
      </div>
    </section>
  );
}

function MiniStat({ label, value, color }) {
  return (
    <div
      style={{
        borderRadius: 18,
        padding: 15,
        background: "rgba(255,255,255,0.035)",
        border: `1px solid ${hexToRgba(color, 0.2)}`,
      }}
    >
      <div
        style={{
          color: "#94a3b8",
          fontSize: "0.72rem",
          fontWeight: 950,
          textTransform: "uppercase",
          letterSpacing: "0.08em",
          marginBottom: 7,
        }}
      >
        {label}
      </div>

      <div
        style={{
          color,
          fontSize: "1.1rem",
          fontWeight: 950,
          letterSpacing: "-0.03em",
        }}
      >
        {value}
      </div>
    </div>
  );
}

function InfoBox({ label, value, color }) {
  return (
    <div
      style={{
        borderRadius: 18,
        padding: 16,
        background: "rgba(255,255,255,0.035)",
        border: `1px solid ${hexToRgba(color, 0.2)}`,
      }}
    >
      <div
        style={{
          color: color || "#93c5fd",
          fontSize: "0.78rem",
          fontWeight: 950,
          textTransform: "uppercase",
          letterSpacing: "0.08em",
          marginBottom: 7,
        }}
      >
        {label}
      </div>

      <div
        style={{
          color: "#e2e8f0",
          fontSize: "0.92rem",
          lineHeight: 1.55,
          fontWeight: 750,
        }}
      >
        {value || "—"}
      </div>
    </div>
  );
}

function GraphHeader({ eyebrow, title, subtitle }) {
  return (
    <div>
      <div
        style={{
          color: "#93c5fd",
          fontSize: "0.74rem",
          fontWeight: 950,
          textTransform: "uppercase",
          letterSpacing: "0.08em",
        }}
      >
        {eyebrow}
      </div>

      <h3
        style={{
          margin: "7px 0 0",
          color: "#ffffff",
          fontSize: "1.25rem",
          fontWeight: 950,
          letterSpacing: "-0.03em",
        }}
      >
        {title}
      </h3>

      <p
        style={{
          margin: "7px 0 0",
          color: "#94a3b8",
          fontSize: "0.9rem",
          lineHeight: 1.55,
        }}
      >
        {subtitle}
      </p>
    </div>
  );
}

function pickNumber(...values) {
  for (const value of values) {
    const numberValue = Number(value);

    if (Number.isFinite(numberValue) && numberValue > 0) {
      return numberValue;
    }
  }

  return 0;
}

function clampPercent(value) {
  const numericValue = Number(value || 0);

  if (!Number.isFinite(numericValue)) return 0;
  if (numericValue < 0) return 0;
  if (numericValue > 100) return 100;

  return numericValue;
}

function formatMoneyFromCents(value) {
  const cents = Number(value || 0);

  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
  }).format(cents / 100);
}

function formatNumber(value) {
  const numberValue = Number(value || 0);

  return new Intl.NumberFormat("en-US").format(numberValue);
}

function formatPercent(value, decimals = 1) {
  const numberValue = Number(value || 0);

  if (!Number.isFinite(numberValue)) return "0%";

  if (numberValue > 0 && numberValue < 1) {
    return `${numberValue.toFixed(2)}%`;
  }

  return `${numberValue.toFixed(decimals)}%`;
}

function hexToRgba(hex, alpha) {
  const safeHex = String(hex || "#ffffff").replace("#", "");

  if (safeHex.length !== 6) {
    return `rgba(255,255,255,${alpha})`;
  }

  const r = parseInt(safeHex.slice(0, 2), 16);
  const g = parseInt(safeHex.slice(2, 4), 16);
  const b = parseInt(safeHex.slice(4, 6), 16);

  return `rgba(${r},${g},${b},${alpha})`;
}

const graphCardStyle = {
  borderRadius: 26,
  padding: 22,
  background:
    "radial-gradient(circle at top right, rgba(59,130,246,0.10), transparent 32%), rgba(15,23,42,0.78)",
  border: "1px solid rgba(255,255,255,0.09)",
  boxShadow: "0 18px 44px rgba(0,0,0,0.24)",
  overflow: "visible",
};