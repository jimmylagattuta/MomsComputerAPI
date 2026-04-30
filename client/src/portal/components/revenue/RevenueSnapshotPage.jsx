import React, { useMemo, useState } from "react";
import RevenueBlankPageShell, {
  RevenuePlaceholderCard,
} from "./RevenueBlankPageShell";

const TARGET_SUBSCRIBERS = 2500;

export default function RevenueSnapshotPage({ kpis }) {
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

    const subscriberProgressPercent = clampPercent(
      (activeSubscribers / TARGET_SUBSCRIBERS) * 100
    );

    const paymentRiskCount =
      billingIssueSubscribers + cancelledSubscribers + expiredSubscribers;

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
        compareLabel: "Current MRR × 12",
        compareValueCents: mrrCents * 12,
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
        compareLabel: "Current MRR",
        compareValueCents: mrrCents,
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
      paymentRiskCount,
      subscriberProgressPercent,
      revenueWindows,
    };
  }, [kpis, dateLabels]);

  const activeRevenueWindow =
    snapshot.revenueWindows.find(
      (window) => window.key === activeRevenueWindowKey
    ) || snapshot.revenueWindows[0];

  const subscriberHealthData = [
    {
      key: "subscribed",
      label: "Subscribed",
      value: snapshot.activeSubscribers,
      color: "#86efac",
      description: "Currently paying subscribers.",
    },
    {
      key: "billing",
      label: "Payment Issue",
      value: snapshot.billingIssueSubscribers,
      color: "#fde68a",
      description:
        "Subscribers whose payment may have failed or whose renewal needs attention.",
    },
    {
      key: "cancelled",
      label: "Cancelled",
      value: snapshot.cancelledSubscribers,
      color: "#fb7185",
      description:
        "Subscribers who cancelled. They may still have access until the billing period ends.",
    },
    {
      key: "expired",
      label: "Expired",
      value: snapshot.expiredSubscribers,
      color: "#fca5a5",
      description: "Subscribers whose paid access has ended.",
    },
  ];

  return (
    <div style={{ display: "grid", gap: 22 }}>
      <RevenueBlankPageShell
        emoji="📊"
        title="Revenue Snapshot"
        subtitle="A clean view of paying subscribers, collected revenue, and subscription status."
      >
        <RevenuePlaceholderCard
          label="Current Paying Subscribers"
          value={formatNumber(snapshot.activeSubscribers)}
          subtext="Users with a currently active paid subscription."
          color="#67e8f9"
        />

        <RevenuePlaceholderCard
          label="Current Monthly Run-Rate"
          value={formatMoneyFromCents(snapshot.mrrCents)}
          subtext="Expected monthly subscription income from current paying subscribers."
          color="#86efac"
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

        <SubscriberProgressWideCard
          activeSubscribers={snapshot.activeSubscribers}
          targetSubscribers={TARGET_SUBSCRIBERS}
          percent={snapshot.subscriberProgressPercent}
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

      <SubscriberHealthPanel data={subscriberHealthData} snapshot={snapshot} />

      <style>
        {`
          .subscriber-health-row:hover,
          .revenue-window-button:hover {
            transform: translateY(-3px);
            box-shadow: 0 18px 38px rgba(0,0,0,0.28) !important;
          }

          .subscriber-health-row:active,
          .revenue-window-button:active {
            transform: translateY(-1px);
          }

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

function SubscriberProgressWideCard({
  activeSubscribers,
  targetSubscribers,
  percent,
}) {
  const remaining = Math.max(targetSubscribers - activeSubscribers, 0);

  return (
    <div
      style={{
        gridColumn: "1 / -1",
        borderRadius: 22,
        padding: 20,
        background:
          "radial-gradient(circle at top right, rgba(103,232,249,0.12), transparent 30%), linear-gradient(135deg, rgba(15,23,42,0.92), rgba(30,41,59,0.74))",
        border: "1px solid rgba(103,232,249,0.22)",
        boxShadow:
          "inset 0 1px 0 rgba(255,255,255,0.05), 0 18px 42px rgba(0,0,0,0.22)",
      }}
    >
      <div
        style={{
          display: "flex",
          justifyContent: "space-between",
          gap: 18,
          alignItems: "flex-start",
          flexWrap: "wrap",
          marginBottom: 14,
        }}
      >
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
            Subscriber Progress
          </div>

          <div
            style={{
              marginTop: 7,
              color: "#ffffff",
              fontSize: "1.15rem",
              fontWeight: 950,
              letterSpacing: "-0.03em",
            }}
          >
            Paying subscribers compared with the subscriber target.
          </div>
        </div>

        <div
          style={{
            color: "#67e8f9",
            fontSize: "clamp(1.7rem, 4vw, 2.8rem)",
            fontWeight: 950,
            letterSpacing: "-0.07em",
            lineHeight: 1,
            whiteSpace: "nowrap",
          }}
        >
          {formatNumber(activeSubscribers)} / {formatNumber(targetSubscribers)}
        </div>
      </div>

      <div
        style={{
          height: 18,
          borderRadius: 999,
          background: "rgba(255,255,255,0.07)",
          border: "1px solid rgba(255,255,255,0.08)",
          overflow: "hidden",
        }}
      >
        <div
          style={{
            width: `${Math.max(percent, activeSubscribers > 0 ? 0.8 : 0)}%`,
            height: "100%",
            borderRadius: 999,
            background: "linear-gradient(90deg, #22d3ee, #a78bfa)",
            boxShadow: "0 0 26px rgba(103,232,249,0.28)",
            transition: "width 0.35s ease",
          }}
        />
      </div>

      <div
        style={{
          marginTop: 12,
          display: "flex",
          justifyContent: "space-between",
          gap: 12,
          flexWrap: "wrap",
          color: "#94a3b8",
          fontSize: "0.84rem",
          fontWeight: 850,
        }}
      >
        <span>{formatPercent(percent, 2)} complete</span>
        <span>{formatNumber(remaining)} remaining</span>
      </div>
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

function SubscriberHealthPanel({ data, snapshot }) {
  const totalHealth = Math.max(
    snapshot.activeSubscribers + snapshot.paymentRiskCount,
    1
  );

  return (
    <section style={graphCardStyle}>
      <GraphHeader
        eyebrow="Subscription Health"
        title="Subscriber Status"
        subtitle="A quick view of subscribed, billing issue, cancelled, and expired subscription records."
      />

      <div style={{ marginTop: 18, display: "grid", gap: 10 }}>
        {data.map((item) => {
          const percent = clampPercent((item.value / totalHealth) * 100);

          return (
            <div
              key={item.key}
              className="subscriber-health-row"
              style={{
                display: "grid",
                gap: 9,
                padding: 13,
                borderRadius: 16,
                background: "rgba(255,255,255,0.035)",
                border: `1px solid ${hexToRgba(item.color, 0.18)}`,
                color: "#ffffff",
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
            </div>
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