import React, { useMemo, useState } from "react";
import RevenueBlankPageShell, {
  RevenuePlaceholderCard,
} from "./RevenueBlankPageShell";

const PLATFORM_CONFIG = {
  app_store: {
    key: "app_store",
    label: "App Store",
    emoji: "🍎",
    color: "#67e8f9",
  },
  google_play: {
    key: "google_play",
    label: "Google Play",
    emoji: "🤖",
    color: "#86efac",
  },
  unknown: {
    key: "unknown",
    label: "Unknown / Manual",
    emoji: "❔",
    color: "#fca5a5",
  },
};

export default function RevenueByPlatformPage({ kpis }) {
  const [activeSectionKey, setActiveSectionKey] = useState("month");
  const [activePlatformKey, setActivePlatformKey] = useState("app_store");

  const dateLabels = useMemo(() => {
    const now = new Date();

    const monthName = now.toLocaleDateString("en-US", {
      month: "long",
    });

    const yearNumber = now.getFullYear();

    return {
      month: {
        eyebrow: "Current Month",
        label: `${monthName} ${yearNumber}`,
        sublabel: "Monthly platform revenue window",
      },
      year: {
        eyebrow: "Current Year",
        label: String(yearNumber),
        sublabel: "Year-to-date platform revenue window",
      },
      total: {
        eyebrow: "All Time",
        label: "All Recorded Revenue",
        sublabel: "Total platform revenue since tracking began",
      },
    };
  }, []);

  const platformReport = useMemo(() => {
    const monthCandidate = buildPlatformSection({
      key: "month",
      eyebrow: "This Month",
      title: "Monthly Platform Revenue",
      subtitle:
        "Revenue collected this month, separated by App Store, Google Play, and unknown platform records.",
      dateLabel: dateLabels.month.label,
      dateEyebrow: dateLabels.month.eyebrow,
      dateSublabel: dateLabels.month.sublabel,
      totalCents: pickNumber(kpis?.revenue_this_month_cents),
      appStoreCents: pickPlatformNumber(kpis, [
        "revenue_by_platform_this_month",
        "monthly_revenue_by_platform",
        "current_month_revenue_by_platform",
        "revenue_this_month_by_platform",
      ]),
      googlePlayCents: pickPlatformNumber(
        kpis,
        [
          "revenue_by_platform_this_month",
          "monthly_revenue_by_platform",
          "current_month_revenue_by_platform",
          "revenue_this_month_by_platform",
        ],
        "google_play"
      ),
      unknownCents: pickPlatformNumber(
        kpis,
        [
          "revenue_by_platform_this_month",
          "monthly_revenue_by_platform",
          "current_month_revenue_by_platform",
          "revenue_this_month_by_platform",
        ],
        "unknown"
      ),
      fallbackMessage:
        "Monthly platform split is not being returned yet. Add revenue_by_platform_this_month with APP_STORE and PLAY_STORE totals.",
    });

    const yearCandidate = buildPlatformSection({
      key: "year",
      eyebrow: "This Year",
      title: "Yearly Platform Revenue",
      subtitle:
        "Year-to-date revenue, separated by App Store, Google Play, and unknown platform records.",
      dateLabel: dateLabels.year.label,
      dateEyebrow: dateLabels.year.eyebrow,
      dateSublabel: dateLabels.year.sublabel,
      totalCents: pickNumber(kpis?.revenue_this_year_cents),
      appStoreCents: pickPlatformNumber(kpis, [
        "revenue_by_platform_this_year",
        "yearly_revenue_by_platform",
        "current_year_revenue_by_platform",
        "revenue_this_year_by_platform",
      ]),
      googlePlayCents: pickPlatformNumber(
        kpis,
        [
          "revenue_by_platform_this_year",
          "yearly_revenue_by_platform",
          "current_year_revenue_by_platform",
          "revenue_this_year_by_platform",
        ],
        "google_play"
      ),
      unknownCents: pickPlatformNumber(
        kpis,
        [
          "revenue_by_platform_this_year",
          "yearly_revenue_by_platform",
          "current_year_revenue_by_platform",
          "revenue_this_year_by_platform",
        ],
        "unknown"
      ),
      fallbackMessage:
        "Yearly platform split is not being returned yet. Add revenue_by_platform_this_year with APP_STORE and PLAY_STORE totals.",
    });

    const totalCandidate = buildPlatformSection({
      key: "total",
      eyebrow: "All Time",
      title: "Total Platform Revenue",
      subtitle:
        "All recorded platform revenue, separated by App Store, Google Play, and unknown platform records.",
      dateLabel: dateLabels.total.label,
      dateEyebrow: dateLabels.total.eyebrow,
      dateSublabel: dateLabels.total.sublabel,
      totalCents: pickNumber(kpis?.total_revenue_cents),
      appStoreCents: pickPlatformNumber(kpis, [
        "revenue_by_platform",
        "total_revenue_by_platform",
        "all_time_revenue_by_platform",
      ]),
      googlePlayCents: pickPlatformNumber(
        kpis,
        [
          "revenue_by_platform",
          "total_revenue_by_platform",
          "all_time_revenue_by_platform",
        ],
        "google_play"
      ),
      unknownCents: pickPlatformNumber(
        kpis,
        [
          "revenue_by_platform",
          "total_revenue_by_platform",
          "all_time_revenue_by_platform",
        ],
        "unknown"
      ),
      fallbackMessage:
        "Total platform split is not being returned yet. Add revenue_by_platform with APP_STORE and PLAY_STORE totals.",
    });

    const total = normalizeUnknown(totalCandidate);

    const year =
      yearCandidate.mappedRevenueCents > 0
        ? normalizeUnknown(yearCandidate)
        : total.totalCents > 0 &&
          pickNumber(kpis?.revenue_this_year_cents) === total.totalCents
        ? {
            ...total,
            key: "year",
            eyebrow: "This Year",
            title: "Yearly Platform Revenue",
            subtitle:
              "Year-to-date revenue by platform. This is using the total platform split because yearly revenue currently matches total revenue.",
            dateLabel: dateLabels.year.label,
            dateEyebrow: dateLabels.year.eyebrow,
            dateSublabel: dateLabels.year.sublabel,
            fallbackMessage:
              "Using total platform split because current year revenue equals total revenue.",
          }
        : normalizeUnknown(yearCandidate);

    const month = normalizeUnknown(monthCandidate);

    const sections = [month, year, total];

    const grandTotalCents = pickNumber(kpis?.total_revenue_cents);
    const currentMonthCents = pickNumber(kpis?.revenue_this_month_cents);
    const currentYearCents = pickNumber(kpis?.revenue_this_year_cents);

    return {
      month,
      year,
      total,
      sections,
      grandTotalCents,
      currentMonthCents,
      currentYearCents,
    };
  }, [kpis, dateLabels]);

  const activeSection =
    platformReport.sections.find((section) => section.key === activeSectionKey) ||
    platformReport.month;

  const activePlatform =
    activeSection.platforms.find((platform) => platform.key === activePlatformKey) ||
    activeSection.platforms[0];

  return (
    <div style={{ display: "grid", gap: 22 }}>
      <RevenueBlankPageShell
        emoji="📱"
        title="Revenue by Platform"
        subtitle="Platform revenue grouped into monthly, yearly, and total sections."
      >
        <RevenuePlaceholderCard
          label="This Month"
          value={formatMoneyFromCents(platformReport.currentMonthCents)}
          subtext="Total subscription revenue collected this month."
          color="#67e8f9"
        />

        <RevenuePlaceholderCard
          label="This Year"
          value={formatMoneyFromCents(platformReport.currentYearCents)}
          subtext="Year-to-date subscription revenue."
          color="#fcd34d"
        />

        <RevenuePlaceholderCard
          label="Total Revenue"
          value={formatMoneyFromCents(platformReport.grandTotalCents)}
          subtext="All recorded subscription revenue."
          color="#c4b5fd"
        />

        <RevenuePlaceholderCard
          label="App Store Total"
          value={formatMoneyFromCents(platformReport.total.appStoreCents)}
          subtext="All-time revenue tied to Apple App Store purchases."
          color="#67e8f9"
        />

        <RevenuePlaceholderCard
          label="Google Play Total"
          value={formatMoneyFromCents(platformReport.total.googlePlayCents)}
          subtext="All-time revenue tied to Google Play purchases."
          color="#86efac"
        />

        <RevenuePlaceholderCard
          label="Unknown / Manual Total"
          value={formatMoneyFromCents(platformReport.total.unknownCents)}
          subtext="All-time revenue that is not clearly mapped to Apple or Google."
          color="#fca5a5"
        />
      </RevenueBlankPageShell>

      <FancyDateBanner section={activeSection} />

      <PlatformPeriodTabs
        sections={platformReport.sections}
        activeSectionKey={activeSectionKey}
        onSelectSection={(sectionKey) => {
          setActiveSectionKey(sectionKey);
          setActivePlatformKey("app_store");
        }}
      />

      <section
        className="platform-two-column"
        style={{
          display: "grid",
          gridTemplateColumns: "minmax(0, 1.15fr) minmax(320px, 0.85fr)",
          gap: 18,
        }}
      >
        <PlatformSectionBoard
          section={activeSection}
          activePlatformKey={activePlatformKey}
          onSelectPlatform={setActivePlatformKey}
        />

        <PlatformInspector section={activeSection} platform={activePlatform} />
      </section>

      <section
        style={{
          display: "grid",
          gridTemplateColumns: "repeat(auto-fit, minmax(260px, 1fr))",
          gap: 18,
        }}
      >
        {platformReport.sections.map((section) => (
          <PlatformSummaryCard
            key={section.key}
            section={section}
            onSelectSection={() => {
              setActiveSectionKey(section.key);
              setActivePlatformKey("app_store");
            }}
          />
        ))}
      </section>

      <style>
        {`
          .platform-section-button:hover,
          .platform-row:hover,
          .platform-summary-card:hover {
            transform: translateY(-3px);
            box-shadow: 0 18px 38px rgba(0,0,0,0.28) !important;
          }

          .platform-section-button:active,
          .platform-row:active,
          .platform-summary-card:active {
            transform: translateY(-1px);
          }

          .platform-section-button:focus-visible,
          .platform-row:focus-visible,
          .platform-summary-card:focus-visible {
            outline: 2px solid rgba(147,197,253,0.72);
            outline-offset: 4px;
          }

          @media (max-width: 940px) {
            .platform-two-column {
              grid-template-columns: 1fr !important;
            }
          }
        `}
      </style>
    </div>
  );
}

function FancyDateBanner({ section }) {
  return (
    <section
      style={{
        borderRadius: 28,
        padding: "24px 26px",
        background:
          "radial-gradient(circle at top left, rgba(34,211,238,0.18), transparent 28%), radial-gradient(circle at top right, rgba(168,85,247,0.16), transparent 32%), linear-gradient(135deg, rgba(15,23,42,0.96), rgba(30,41,59,0.72))",
        border: "1px solid rgba(147,197,253,0.18)",
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
          background: "rgba(147,197,253,0.08)",
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
              color: "#93c5fd",
              fontSize: "0.78rem",
              fontWeight: 950,
              textTransform: "uppercase",
              letterSpacing: "0.1em",
            }}
          >
            {section.dateEyebrow}
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
            {section.dateLabel}
          </div>

          <div
            style={{
              marginTop: 10,
              color: "#cbd5e1",
              fontSize: "0.98rem",
              fontWeight: 750,
            }}
          >
            {section.dateSublabel}
          </div>
        </div>

        <div
          style={{
            minWidth: 230,
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
            Selected Window
          </div>

          <div
            style={{
              marginTop: 8,
              color: "#ffffff",
              fontSize: "1.65rem",
              fontWeight: 950,
              letterSpacing: "-0.06em",
            }}
          >
            {formatMoneyFromCents(section.totalCents)}
          </div>

          <div
            style={{
              marginTop: 8,
              color: "#93c5fd",
              fontSize: "0.85rem",
              fontWeight: 850,
            }}
          >
            {section.title}
          </div>
        </div>
      </div>
    </section>
  );
}

function PlatformPeriodTabs({ sections, activeSectionKey, onSelectSection }) {
  return (
    <section style={panelStyle}>
      <PanelHeader
        eyebrow="Platform Periods"
        title="Monthly, Yearly, and Total Views"
        subtitle="Switch between the same App Store vs Google Play breakdown across different reporting windows."
      />

      <div
        style={{
          display: "grid",
          gridTemplateColumns: "repeat(auto-fit, minmax(220px, 1fr))",
          gap: 12,
          marginTop: 18,
        }}
      >
        {sections.map((section) => {
          const isActive = activeSectionKey === section.key;

          return (
            <button
              key={section.key}
              type="button"
              onClick={() => onSelectSection(section.key)}
              className="platform-section-button"
              style={{
                borderRadius: 20,
                padding: 16,
                border: isActive
                  ? "1px solid rgba(147,197,253,0.34)"
                  : "1px solid rgba(255,255,255,0.08)",
                background: isActive
                  ? "linear-gradient(135deg, rgba(59,130,246,0.18), rgba(168,85,247,0.13))"
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
                  color: "#93c5fd",
                  fontSize: "0.72rem",
                  fontWeight: 950,
                  textTransform: "uppercase",
                  letterSpacing: "0.08em",
                }}
              >
                {section.eyebrow}
              </div>

              <div
                style={{
                  marginTop: 6,
                  color: "#ffffff",
                  fontSize: "1.05rem",
                  fontWeight: 950,
                }}
              >
                {section.dateLabel}
              </div>

              <div
                style={{
                  marginTop: 10,
                  color: isActive ? "#bfdbfe" : "#cbd5e1",
                  fontSize: "1.4rem",
                  fontWeight: 950,
                  letterSpacing: "-0.05em",
                }}
              >
                {formatMoneyFromCents(section.totalCents)}
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
                {section.mappedRevenueCents > 0
                  ? `${formatMoneyFromCents(
                      section.mappedRevenueCents
                    )} mapped by platform`
                  : section.fallbackMessage}
              </div>
            </button>
          );
        })}
      </div>
    </section>
  );
}

function PlatformSectionBoard({
  section,
  activePlatformKey,
  onSelectPlatform,
}) {
  return (
    <section style={panelStyle}>
      <PanelHeader
        eyebrow={section.eyebrow}
        title={section.title}
        subtitle={section.subtitle}
      />

      <div style={{ display: "grid", gap: 14, marginTop: 18 }}>
        {section.platforms.map((platform) => {
          const isActive = activePlatformKey === platform.key;

          const barWidth = Math.max(
            platform.revenuePercent,
            platform.revenueCents > 0 ? 4 : 1
          );

          return (
            <button
              key={platform.key}
              type="button"
              onMouseEnter={() => onSelectPlatform(platform.key)}
              onFocus={() => onSelectPlatform(platform.key)}
              onClick={() => onSelectPlatform(platform.key)}
              className="platform-row"
              style={{
                border: isActive
                  ? `1px solid ${hexToRgba(platform.color, 0.58)}`
                  : "1px solid rgba(255,255,255,0.08)",
                background: isActive
                  ? hexToRgba(platform.color, 0.11)
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
                      color: platform.color,
                      fontSize: "0.72rem",
                      fontWeight: 950,
                      textTransform: "uppercase",
                      letterSpacing: "0.08em",
                    }}
                  >
                    {platform.emoji} Platform
                  </div>

                  <div
                    style={{
                      color: "#ffffff",
                      fontWeight: 950,
                      fontSize: "0.98rem",
                      marginTop: 4,
                    }}
                  >
                    {platform.label}
                  </div>
                </div>

                <div
                  style={{
                    color: platform.color,
                    fontWeight: 950,
                    fontSize: "1.05rem",
                    whiteSpace: "nowrap",
                  }}
                >
                  {formatMoneyFromCents(platform.revenueCents)}
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
                      platform.color,
                      0.35
                    )}, ${platform.color})`,
                    boxShadow: `0 0 24px ${hexToRgba(platform.color, 0.28)}`,
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
                <span>
                  {formatPercent(platform.revenuePercent, 1)} of this section
                </span>
                <span>
                  {formatMoneyFromCents(platform.revenueCents)} /{" "}
                  {formatMoneyFromCents(section.totalCents)}
                </span>
              </div>
            </button>
          );
        })}
      </div>
    </section>
  );
}

function PlatformInspector({ section, platform }) {
  return (
    <section
      style={{
        ...panelStyle,
        background: `radial-gradient(circle at top right, ${hexToRgba(
          platform.color,
          0.18
        )}, transparent 36%), rgba(15,23,42,0.82)`,
      }}
    >
      <PanelHeader
        eyebrow={`${section.eyebrow} Selected Platform`}
        title={`${platform.emoji} ${platform.label}`}
        subtitle={`${section.dateLabel} • ${section.title}`}
      />

      <div
        style={{
          marginTop: 20,
          borderRadius: 24,
          padding: 22,
          background: "rgba(255,255,255,0.045)",
          border: `1px solid ${hexToRgba(platform.color, 0.24)}`,
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
          {section.dateEyebrow}
        </div>

        <div
          style={{
            marginTop: 5,
            color: "#ffffff",
            fontSize: "1.15rem",
            fontWeight: 950,
          }}
        >
          {section.dateLabel}
        </div>

        <div
          style={{
            marginTop: 14,
            color: platform.color,
            fontSize: "clamp(2rem, 5vw, 3.25rem)",
            fontWeight: 950,
            letterSpacing: "-0.07em",
            lineHeight: 1,
          }}
        >
          {formatMoneyFromCents(platform.revenueCents)}
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
          {platform.description}
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
          label="Platform Share"
          value={formatPercent(platform.revenuePercent, 1)}
          color={platform.color}
        />

        <MiniStat
          label="Section Total"
          value={formatMoneyFromCents(section.totalCents)}
          color="#93c5fd"
        />

        <MiniStat
          label="Mapped Total"
          value={formatMoneyFromCents(section.mappedRevenueCents)}
          color="#c4b5fd"
        />

        <MiniStat
          label="Unmapped"
          value={formatMoneyFromCents(section.unknownCents)}
          color="#fca5a5"
        />
      </div>

      <InfoBox
        label="What this means"
        value={
          section.mappedRevenueCents > 0
            ? `${platform.label} represents ${formatPercent(
                platform.revenuePercent,
                1
              )} of ${section.eyebrow.toLowerCase()} mapped platform revenue.`
            : section.fallbackMessage
        }
        color={platform.color}
      />
    </section>
  );
}

function PlatformSummaryCard({ section, onSelectSection }) {
  return (
    <button
      type="button"
      onClick={onSelectSection}
      className="platform-summary-card"
      style={{
        borderRadius: 26,
        padding: 22,
        background:
          "radial-gradient(circle at top right, rgba(59,130,246,0.10), transparent 32%), rgba(15,23,42,0.78)",
        border: "1px solid rgba(255,255,255,0.09)",
        boxShadow: "0 18px 44px rgba(0,0,0,0.24)",
        cursor: "pointer",
        color: "#ffffff",
        textAlign: "left",
        transition:
          "transform 0.18s ease, border-color 0.18s ease, background 0.18s ease, box-shadow 0.18s ease",
      }}
    >
      <div
        style={{
          color: "#93c5fd",
          fontSize: "0.74rem",
          fontWeight: 950,
          textTransform: "uppercase",
          letterSpacing: "0.08em",
        }}
      >
        {section.eyebrow}
      </div>

      <div
        style={{
          marginTop: 7,
          color: "#ffffff",
          fontSize: "1.35rem",
          fontWeight: 950,
          letterSpacing: "-0.04em",
        }}
      >
        {section.dateLabel}
      </div>

      <div
        style={{
          marginTop: 14,
          color: "#ffffff",
          fontSize: "2rem",
          fontWeight: 950,
          letterSpacing: "-0.06em",
        }}
      >
        {formatMoneyFromCents(section.totalCents)}
      </div>

      <div style={{ display: "grid", gap: 10, marginTop: 16 }}>
        {section.platforms.map((platform) => (
          <div key={platform.key}>
            <div
              style={{
                display: "flex",
                justifyContent: "space-between",
                gap: 10,
                color: "#cbd5e1",
                fontSize: "0.84rem",
                fontWeight: 850,
                marginBottom: 6,
              }}
            >
              <span>
                {platform.emoji} {platform.label}
              </span>

              <span style={{ color: platform.color }}>
                {formatMoneyFromCents(platform.revenueCents)}
              </span>
            </div>

            <div
              style={{
                height: 8,
                borderRadius: 999,
                background: "rgba(255,255,255,0.07)",
                overflow: "hidden",
              }}
            >
              <div
                style={{
                  width: `${Math.max(
                    platform.revenuePercent,
                    platform.revenueCents > 0 ? 4 : 1
                  )}%`,
                  height: "100%",
                  borderRadius: 999,
                  background: platform.color,
                }}
              />
            </div>
          </div>
        ))}
      </div>
    </button>
  );
}

function buildPlatformSection({
  key,
  eyebrow,
  title,
  subtitle,
  dateLabel,
  dateEyebrow,
  dateSublabel,
  totalCents,
  appStoreCents,
  googlePlayCents,
  unknownCents,
  fallbackMessage,
}) {
  const mappedRevenueCents = appStoreCents + googlePlayCents + unknownCents;
  const sectionTotalCents = totalCents > 0 ? totalCents : mappedRevenueCents;

  const platforms = [
    {
      ...PLATFORM_CONFIG.app_store,
      revenueCents: appStoreCents,
      revenuePercent: percentOf(appStoreCents, sectionTotalCents),
      description: `${PLATFORM_CONFIG.app_store.label} revenue for ${eyebrow.toLowerCase()}.`,
    },
    {
      ...PLATFORM_CONFIG.google_play,
      revenueCents: googlePlayCents,
      revenuePercent: percentOf(googlePlayCents, sectionTotalCents),
      description: `${PLATFORM_CONFIG.google_play.label} revenue for ${eyebrow.toLowerCase()}.`,
    },
    {
      ...PLATFORM_CONFIG.unknown,
      revenueCents: unknownCents,
      revenuePercent: percentOf(unknownCents, sectionTotalCents),
      description: `${PLATFORM_CONFIG.unknown.label} revenue for ${eyebrow.toLowerCase()}.`,
    },
  ];

  return {
    key,
    eyebrow,
    title,
    subtitle,
    dateLabel,
    dateEyebrow,
    dateSublabel,
    totalCents: sectionTotalCents,
    appStoreCents,
    googlePlayCents,
    unknownCents,
    mappedRevenueCents,
    fallbackMessage,
    platforms,
  };
}

function normalizeUnknown(section) {
  const known = section.appStoreCents + section.googlePlayCents;
  const normalizedUnknown =
    section.unknownCents > 0
      ? section.unknownCents
      : Math.max(section.totalCents - known, 0);

  return buildPlatformSection({
    key: section.key,
    eyebrow: section.eyebrow,
    title: section.title,
    subtitle: section.subtitle,
    dateLabel: section.dateLabel,
    dateEyebrow: section.dateEyebrow,
    dateSublabel: section.dateSublabel,
    totalCents: section.totalCents,
    appStoreCents: section.appStoreCents,
    googlePlayCents: section.googlePlayCents,
    unknownCents: normalizedUnknown,
    fallbackMessage: section.fallbackMessage,
  });
}

function pickPlatformNumber(kpis, objectKeys, platform = "app_store") {
  const platformKeys =
    platform === "app_store"
      ? ["APP_STORE", "app_store", "IOS", "ios", "APPLE", "apple"]
      : platform === "google_play"
      ? [
          "PLAY_STORE",
          "GOOGLE_PLAY",
          "play_store",
          "google_play",
          "ANDROID",
          "android",
        ]
      : ["UNKNOWN", "unknown", "MANUAL", "manual", "OTHER", "other"];

  for (const objectKey of objectKeys) {
    const object = kpis?.[objectKey];

    if (!object || typeof object !== "object") continue;

    for (const platformKey of platformKeys) {
      const value = object?.[platformKey];

      if (Number.isFinite(Number(value)) && Number(value) > 0) {
        return Number(value);
      }
    }
  }

  return 0;
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

  return (numericValue / numericTotal) * 100;
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

const panelStyle = {
  borderRadius: 26,
  padding: 22,
  background:
    "radial-gradient(circle at top right, rgba(59,130,246,0.10), transparent 32%), rgba(15,23,42,0.78)",
  border: "1px solid rgba(255,255,255,0.09)",
  boxShadow: "0 18px 44px rgba(0,0,0,0.24)",
  overflow: "hidden",
};