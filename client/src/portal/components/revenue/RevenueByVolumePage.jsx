import React, { useMemo, useState } from "react";
import RevenueBlankPageShell, {
  RevenuePlaceholderCard,
} from "./RevenueBlankPageShell";

const VOLUME_CONFIG = {
  active_subscribers: {
    key: "active_subscribers",
    label: "Active Subscribers",
    emoji: "✅",
    color: "#86efac",
    description:
      "Users with active subscription access. This is the strongest health signal.",
  },
  paying_users: {
    key: "paying_users",
    label: "Paying Users",
    emoji: "💳",
    color: "#67e8f9",
    description:
      "Users who have at least one recorded subscription transaction.",
  },
  total_users: {
    key: "total_users",
    label: "Total Users",
    emoji: "👥",
    color: "#c4b5fd",
    description:
      "All registered users in the system, including free, inactive, paid, cancelled, and expired.",
  },
  billing_issues: {
    key: "billing_issues",
    label: "Billing Issues",
    emoji: "⚠️",
    color: "#fde68a",
    description:
      "Subscriptions that need payment attention. These are at-risk accounts.",
  },
  cancelled: {
    key: "cancelled",
    label: "Cancelled",
    emoji: "🛑",
    color: "#fb7185",
    description:
      "Users who cancelled. They may still have access until the end of the current period.",
  },
  expired: {
    key: "expired",
    label: "Expired",
    emoji: "⌛",
    color: "#fca5a5",
    description:
      "Users whose paid access has ended. These are lost or inactive subscription accounts.",
  },
};

export default function RevenueByVolumePage({ kpis }) {
  const [activeMetricKey, setActiveMetricKey] = useState("active_subscribers");

  const volumeReport = useMemo(() => {
    const activeSubscribers = pickNumber(kpis?.active_subscribers);
    const billingIssues = pickNumber(kpis?.billing_issue_subscribers);
    const cancelled = pickNumber(kpis?.cancelled_subscribers);
    const expired = pickNumber(kpis?.expired_subscribers);
    const payingUsers = pickNumber(kpis?.paying_users);
    const totalUsers = pickNumber(kpis?.total_users);

    const subscriptionPopulation =
      activeSubscribers + billingIssues + cancelled + expired;

    const riskAccounts = billingIssues + cancelled + expired;

    const healthyPercent = percentOf(activeSubscribers, subscriptionPopulation);
    const conversionPercent = percentOf(activeSubscribers, totalUsers);
    const riskPercent = percentOf(riskAccounts, subscriptionPopulation);
    const billingIssuePercent = percentOf(billingIssues, subscriptionPopulation);
    const cancelledPercent = percentOf(cancelled, subscriptionPopulation);
    const expiredPercent = percentOf(expired, subscriptionPopulation);

    const metrics = [
      {
        ...VOLUME_CONFIG.active_subscribers,
        value: activeSubscribers,
        percent: healthyPercent,
        denominator: subscriptionPopulation,
        summary:
          activeSubscribers > 0
            ? `${formatNumber(activeSubscribers)} active subscribers out of ${formatNumber(
                subscriptionPopulation
              )} tracked subscription records.`
            : "No active subscribers are currently recorded.",
        meaning:
          "This is the core count for subscription health. The higher this is compared with cancelled, expired, and billing issue accounts, the stronger the subscription base is.",
      },
      {
        ...VOLUME_CONFIG.paying_users,
        value: payingUsers,
        percent: percentOf(payingUsers, totalUsers),
        denominator: totalUsers,
        summary:
          payingUsers > 0
            ? `${formatNumber(payingUsers)} users have at least one payment transaction.`
            : "No paying users are currently recorded.",
        meaning:
          "This shows how many users have ever converted into a paying customer, even if their subscription status later changed.",
      },
      {
        ...VOLUME_CONFIG.total_users,
        value: totalUsers,
        percent: 100,
        denominator: totalUsers,
        summary: `${formatNumber(totalUsers)} total registered users are currently in the system.`,
        meaning:
          "This is the full user base. Compare this against active subscribers to understand conversion.",
      },
      {
        ...VOLUME_CONFIG.billing_issues,
        value: billingIssues,
        percent: billingIssuePercent,
        denominator: subscriptionPopulation,
        summary:
          billingIssues > 0
            ? `${formatNumber(billingIssues)} subscriptions currently have billing issues.`
            : "No billing issue subscriptions are currently recorded.",
        meaning:
          "Billing issues are recoverable risk. These users may still want the product, but payment needs attention.",
      },
      {
        ...VOLUME_CONFIG.cancelled,
        value: cancelled,
        percent: cancelledPercent,
        denominator: subscriptionPopulation,
        summary:
          cancelled > 0
            ? `${formatNumber(cancelled)} subscriptions are marked cancelled.`
            : "No cancelled subscriptions are currently recorded.",
        meaning:
          "Cancelled users may still have access until the end of their current period. This is churn pressure, but not always expired access yet.",
      },
      {
        ...VOLUME_CONFIG.expired,
        value: expired,
        percent: expiredPercent,
        denominator: subscriptionPopulation,
        summary:
          expired > 0
            ? `${formatNumber(expired)} subscriptions are expired.`
            : "No expired subscriptions are currently recorded.",
        meaning:
          "Expired users no longer have paid access. This is the clearest lost-subscription bucket.",
      },
    ];

    const activeMetric =
      metrics.find((metric) => metric.key === activeMetricKey) || metrics[0];

    return {
      activeSubscribers,
      billingIssues,
      cancelled,
      expired,
      payingUsers,
      totalUsers,
      subscriptionPopulation,
      riskAccounts,
      healthyPercent,
      conversionPercent,
      riskPercent,
      metrics,
      activeMetric,
    };
  }, [kpis, activeMetricKey]);

  return (
    <div style={{ display: "grid", gap: 22 }}>
      <RevenueBlankPageShell
        emoji="📈"
        title="Activity Volume"
        subtitle="A count-based view of subscription movement, account health, user conversion, and billing risk."
      >
        <RevenuePlaceholderCard
          label="Active Subscribers"
          value={formatNumber(volumeReport.activeSubscribers)}
          subtext="Current subscriptions with active access."
          color="#86efac"
        />

        <RevenuePlaceholderCard
          label="Paying Users"
          value={formatNumber(volumeReport.payingUsers)}
          subtext="Users with at least one recorded payment."
          color="#67e8f9"
        />

        <RevenuePlaceholderCard
          label="Total Users"
          value={formatNumber(volumeReport.totalUsers)}
          subtext="All registered users in the system."
          color="#c4b5fd"
        />

        <RevenuePlaceholderCard
          label="Billing Issues"
          value={formatNumber(volumeReport.billingIssues)}
          subtext="Accounts needing payment attention."
          color="#fde68a"
        />

        <RevenuePlaceholderCard
          label="Cancelled"
          value={formatNumber(volumeReport.cancelled)}
          subtext="Cancelled subscriptions that may still be in their access window."
          color="#fb7185"
        />

        <RevenuePlaceholderCard
          label="Expired"
          value={formatNumber(volumeReport.expired)}
          subtext="Subscriptions whose paid access has ended."
          color="#fca5a5"
        />

        <RevenuePlaceholderCard
          label="Healthy Base"
          value={formatPercent(volumeReport.healthyPercent, 1)}
          subtext="Active subscribers compared with tracked subscription statuses."
          color="#86efac"
        />

        <RevenuePlaceholderCard
          label="User Conversion"
          value={formatPercent(volumeReport.conversionPercent, 1)}
          subtext="Active subscribers compared with total registered users."
          color="#93c5fd"
        />

        <RevenuePlaceholderCard
          label="Risk Accounts"
          value={formatNumber(volumeReport.riskAccounts)}
          subtext="Billing issue, cancelled, and expired subscriptions combined."
          color="#fca5a5"
        />
      </RevenueBlankPageShell>

      <ActivitySummaryBanner volumeReport={volumeReport} />

      <section
        className="activity-volume-two-column"
        style={{
          display: "grid",
          gridTemplateColumns: "minmax(0, 1.15fr) minmax(320px, 0.85fr)",
          gap: 18,
        }}
      >
        <ActivityVolumeBoard
          metrics={volumeReport.metrics}
          activeMetricKey={activeMetricKey}
          onSelectMetric={setActiveMetricKey}
        />

        <ActivityMetricInspector metric={volumeReport.activeMetric} />
      </section>

      <section
        className="activity-volume-two-column"
        style={{
          display: "grid",
          gridTemplateColumns: "minmax(0, 1.15fr) minmax(320px, 0.85fr)",
          gap: 18,
        }}
      >
        <ConversionHealthPanel volumeReport={volumeReport} />

        <RiskBreakdownPanel volumeReport={volumeReport} />
      </section>

      <style>
        {`
          .activity-volume-row:hover,
          .activity-health-card:hover {
            transform: translateY(-3px);
            box-shadow: 0 18px 38px rgba(0,0,0,0.28) !important;
          }

          .activity-volume-row:active,
          .activity-health-card:active {
            transform: translateY(-1px);
          }

          .activity-volume-row:focus-visible,
          .activity-health-card:focus-visible {
            outline: 2px solid rgba(147,197,253,0.72);
            outline-offset: 4px;
          }

          @media (max-width: 940px) {
            .activity-volume-two-column {
              grid-template-columns: 1fr !important;
            }
          }
        `}
      </style>
    </div>
  );
}

function ActivitySummaryBanner({ volumeReport }) {
  return (
    <section
      style={{
        borderRadius: 28,
        padding: "24px 26px",
        background:
          "radial-gradient(circle at top left, rgba(34,197,94,0.16), transparent 28%), radial-gradient(circle at top right, rgba(34,211,238,0.14), transparent 32%), linear-gradient(135deg, rgba(15,23,42,0.96), rgba(30,41,59,0.72))",
        border: "1px solid rgba(134,239,172,0.18)",
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
          background: "rgba(134,239,172,0.08)",
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
              color: "#86efac",
              fontSize: "0.78rem",
              fontWeight: 950,
              textTransform: "uppercase",
              letterSpacing: "0.1em",
            }}
          >
            Activity Health
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
            {formatPercent(volumeReport.healthyPercent, 1)} Healthy
          </div>

          <div
            style={{
              marginTop: 10,
              color: "#cbd5e1",
              fontSize: "0.98rem",
              fontWeight: 750,
            }}
          >
            Active subscribers compared with total tracked subscription statuses.
          </div>
        </div>

        <div
          style={{
            minWidth: 250,
            borderRadius: 24,
            padding: 18,
            background: "rgba(255,255,255,0.045)",
            border: "1px solid rgba(255,255,255,0.10)",
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
            Active / Risk
          </div>

          <div
            style={{
              marginTop: 8,
              color: "#ffffff",
              fontSize: "1.85rem",
              fontWeight: 950,
              letterSpacing: "-0.06em",
            }}
          >
            {formatNumber(volumeReport.activeSubscribers)} /{" "}
            {formatNumber(volumeReport.riskAccounts)}
          </div>

          <div
            style={{
              marginTop: 8,
              color: "#cbd5e1",
              fontSize: "0.85rem",
              fontWeight: 850,
            }}
          >
            Active subscribers vs. at-risk subscription records
          </div>
        </div>
      </div>
    </section>
  );
}

function ActivityVolumeBoard({ metrics, activeMetricKey, onSelectMetric }) {
  return (
    <section style={panelStyle}>
      <PanelHeader
        eyebrow="Activity Volume"
        title="Subscription Movement"
        subtitle="These bars show count-based activity, not dollar totals."
      />

      <div style={{ display: "grid", gap: 14, marginTop: 18 }}>
        {metrics.map((metric) => {
          const isActive = activeMetricKey === metric.key;
          const barWidth = Math.max(metric.percent, metric.value > 0 ? 4 : 1);

          return (
            <button
              key={metric.key}
              type="button"
              onMouseEnter={() => onSelectMetric(metric.key)}
              onFocus={() => onSelectMetric(metric.key)}
              onClick={() => onSelectMetric(metric.key)}
              className="activity-volume-row"
              style={{
                border: isActive
                  ? `1px solid ${hexToRgba(metric.color, 0.58)}`
                  : "1px solid rgba(255,255,255,0.08)",
                background: isActive
                  ? hexToRgba(metric.color, 0.11)
                  : "rgba(255,255,255,0.035)",
                borderRadius: 18,
                padding: 15,
                cursor: "pointer",
                textAlign: "left",
                color: "#ffffff",
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
                      color: metric.color,
                      fontSize: "0.72rem",
                      fontWeight: 950,
                      textTransform: "uppercase",
                      letterSpacing: "0.08em",
                    }}
                  >
                    {metric.emoji} Count
                  </div>

                  <div
                    style={{
                      color: "#ffffff",
                      fontWeight: 950,
                      fontSize: "0.98rem",
                      marginTop: 4,
                    }}
                  >
                    {metric.label}
                  </div>
                </div>

                <div
                  style={{
                    color: metric.color,
                    fontWeight: 950,
                    fontSize: "1.2rem",
                    whiteSpace: "nowrap",
                  }}
                >
                  {formatNumber(metric.value)}
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
                    width: `${barWidth}%`,
                    height: "100%",
                    borderRadius: 999,
                    background: `linear-gradient(90deg, ${hexToRgba(
                      metric.color,
                      0.35
                    )}, ${metric.color})`,
                    boxShadow: `0 0 24px ${hexToRgba(metric.color, 0.28)}`,
                    transition: "width 0.35s ease",
                  }}
                />
              </div>

              <div
                style={{
                  display: "flex",
                  justifyContent: "space-between",
                  gap: 12,
                  flexWrap: "wrap",
                  marginTop: 8,
                  color: "#94a3b8",
                  fontSize: "0.8rem",
                  fontWeight: 800,
                }}
              >
                <span>{formatPercent(metric.percent, 1)}</span>
                <span>
                  {formatNumber(metric.value)} /{" "}
                  {formatNumber(metric.denominator)}
                </span>
              </div>
            </button>
          );
        })}
      </div>
    </section>
  );
}

function ActivityMetricInspector({ metric }) {
  return (
    <section
      style={{
        ...panelStyle,
        background: `radial-gradient(circle at top right, ${hexToRgba(
          metric.color,
          0.18
        )}, transparent 36%), rgba(15,23,42,0.82)`,
      }}
    >
      <PanelHeader
        eyebrow="Selected Activity"
        title={`${metric.emoji} ${metric.label}`}
        subtitle={metric.description}
      />

      <div
        style={{
          marginTop: 20,
          borderRadius: 24,
          padding: 22,
          background: "rgba(255,255,255,0.045)",
          border: `1px solid ${hexToRgba(metric.color, 0.24)}`,
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
          Current Count
        </div>

        <div
          style={{
            marginTop: 8,
            color: metric.color,
            fontSize: "clamp(2.2rem, 6vw, 4rem)",
            fontWeight: 950,
            letterSpacing: "-0.08em",
            lineHeight: 1,
          }}
        >
          {formatNumber(metric.value)}
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
          {metric.summary}
        </p>
      </div>

      <div
        style={{
          display: "grid",
          gridTemplateColumns: "repeat(2, minmax(0, 1fr))",
          gap: 12,
          marginTop: 14,
        }}
      >
        <MiniStat
          label="Share"
          value={formatPercent(metric.percent, 1)}
          color={metric.color}
        />

        <MiniStat
          label="Compared Against"
          value={formatNumber(metric.denominator)}
          color="#93c5fd"
        />
      </div>

      <InfoBox label="What this means" value={metric.meaning} color={metric.color} />
    </section>
  );
}

function ConversionHealthPanel({ volumeReport }) {
  return (
    <section style={panelStyle}>
      <PanelHeader
        eyebrow="Conversion"
        title="Users Becoming Subscribers"
        subtitle="This compares active subscribers against the full registered user base."
      />

      <div style={{ display: "grid", gap: 14, marginTop: 18 }}>
        <HealthCard
          eyebrow="User Conversion"
          title="Active Subscribers / Total Users"
          value={formatPercent(volumeReport.conversionPercent, 1)}
          color="#93c5fd"
          leftLabel={`${formatNumber(volumeReport.activeSubscribers)} active`}
          rightLabel={`${formatNumber(volumeReport.totalUsers)} total users`}
          percent={volumeReport.conversionPercent}
        />

        <HealthCard
          eyebrow="Paying History"
          title="Paying Users / Total Users"
          value={formatPercent(
            percentOf(volumeReport.payingUsers, volumeReport.totalUsers),
            1
          )}
          color="#67e8f9"
          leftLabel={`${formatNumber(volumeReport.payingUsers)} paying users`}
          rightLabel={`${formatNumber(volumeReport.totalUsers)} total users`}
          percent={percentOf(volumeReport.payingUsers, volumeReport.totalUsers)}
        />
      </div>
    </section>
  );
}

function RiskBreakdownPanel({ volumeReport }) {
  return (
    <section style={panelStyle}>
      <PanelHeader
        eyebrow="Risk"
        title="At-Risk Subscription Volume"
        subtitle="Billing issues, cancelled subscriptions, and expired subscriptions grouped together."
      />

      <div style={{ display: "grid", gap: 14, marginTop: 18 }}>
        <HealthCard
          eyebrow="Risk Share"
          title="Risk Accounts / Subscription Population"
          value={formatPercent(volumeReport.riskPercent, 1)}
          color="#fca5a5"
          leftLabel={`${formatNumber(volumeReport.riskAccounts)} risk`}
          rightLabel={`${formatNumber(
            volumeReport.subscriptionPopulation
          )} subscription records`}
          percent={volumeReport.riskPercent}
        />

        <InfoBox
          label="What this means"
          value="If this number starts climbing, the business may still have users, but more of them are drifting into billing problems, cancellation, or expired access."
          color="#fca5a5"
        />
      </div>
    </section>
  );
}

function HealthCard({
  eyebrow,
  title,
  value,
  color,
  leftLabel,
  rightLabel,
  percent,
}) {
  const barWidth = Math.max(percent, percent > 0 ? 4 : 1);

  return (
    <div
      className="activity-health-card"
      style={{
        borderRadius: 20,
        padding: 16,
        background: "rgba(255,255,255,0.035)",
        border: `1px solid ${hexToRgba(color, 0.24)}`,
        transition:
          "transform 0.18s ease, border-color 0.18s ease, background 0.18s ease, box-shadow 0.18s ease",
      }}
    >
      <div
        style={{
          color,
          fontSize: "0.72rem",
          fontWeight: 950,
          textTransform: "uppercase",
          letterSpacing: "0.08em",
        }}
      >
        {eyebrow}
      </div>

      <div
        style={{
          marginTop: 6,
          color: "#ffffff",
          fontSize: "1rem",
          fontWeight: 950,
        }}
      >
        {title}
      </div>

      <div
        style={{
          marginTop: 12,
          color,
          fontSize: "2rem",
          fontWeight: 950,
          letterSpacing: "-0.06em",
        }}
      >
        {value}
      </div>

      <div
        style={{
          height: 12,
          borderRadius: 999,
          background: "rgba(255,255,255,0.07)",
          overflow: "hidden",
          marginTop: 12,
        }}
      >
        <div
          style={{
            width: `${barWidth}%`,
            height: "100%",
            borderRadius: 999,
            background: color,
            boxShadow: `0 0 18px ${hexToRgba(color, 0.25)}`,
          }}
        />
      </div>

      <div
        style={{
          marginTop: 8,
          display: "flex",
          justifyContent: "space-between",
          gap: 10,
          flexWrap: "wrap",
          color: "#94a3b8",
          fontSize: "0.8rem",
          fontWeight: 800,
        }}
      >
        <span>{leftLabel}</span>
        <span>{rightLabel}</span>
      </div>
    </div>
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
        marginTop: 14,
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

function PanelHeader({ eyebrow, title, subtitle }) {
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

function percentOf(value, total) {
  const numericValue = Number(value || 0);
  const numericTotal = Number(total || 0);

  if (!Number.isFinite(numericValue) || !Number.isFinite(numericTotal)) return 0;
  if (numericTotal <= 0) return 0;

  return clampPercent((numericValue / numericTotal) * 100);
}

function clampPercent(value) {
  const numericValue = Number(value || 0);

  if (!Number.isFinite(numericValue)) return 0;
  if (numericValue < 0) return 0;
  if (numericValue > 100) return 100;

  return numericValue;
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

const panelStyle = {
  borderRadius: 26,
  padding: 22,
  background:
    "radial-gradient(circle at top right, rgba(59,130,246,0.10), transparent 32%), rgba(15,23,42,0.78)",
  border: "1px solid rgba(255,255,255,0.09)",
  boxShadow: "0 18px 44px rgba(0,0,0,0.24)",
  overflow: "hidden",
};