import React, { useEffect, useMemo, useRef, useState } from "react";
import RevenueNestedMenu from "./RevenueNestedMenu";
import RevenueSnapshotPage from "./RevenueSnapshotPage";
import RevenueByVolumePage from "./RevenueByVolumePage";
import RevenueByPlatformPage from "./RevenueByPlatformPage";
import RevenueTaxExportPage from "./RevenueTaxExportPage";
import {
  cardStyle,
  sectionSubtextStyle,
  sectionTitleStyle,
} from "../../styles/portalStyles";

const REVENUE_PAGES = {
  snapshot: {
    title: "Snapshot",
    eyebrow: "Revenue Command Center",
    subtitle:
      "A clean high-level view of current revenue, paying subscribers, and business health.",
    emoji: "📊",
  },
  revenue_by_volume: {
    title: "Activity Volume",
    eyebrow: "Activity Analysis",
    subtitle:
      "Review count-based activity such as purchases, renewals, cancellations, billing events, and subscription movement.",
    emoji: "📈",
  },
  revenue_by_platform: {
    title: "Revenue by Platform",
    eyebrow: "Platform Analysis",
    subtitle:
      "Compare subscription revenue and subscriber activity from the App Store, Google Play, and any unknown or manually recorded platforms.",
    emoji: "📱",
  },
  tax_export: {
    title: "Tax / Export View",
    eyebrow: "Accounting View",
    subtitle:
      "A clean accounting view for reviewing yearly revenue, monthly totals, and export-ready transaction records.",
    emoji: "🧾",
  },
};

export default function RevenueOverviewPanel({ kpis, onReady }) {
  const readyNotifiedRef = useRef(false);
  const [activeRevenuePage, setActiveRevenuePage] = useState("snapshot");

  useEffect(() => {
    if (readyNotifiedRef.current) return;

    readyNotifiedRef.current = true;

    window.requestAnimationFrame(() => {
      window.requestAnimationFrame(() => {
        window.setTimeout(() => {
          if (typeof onReady === "function") {
            onReady();
          }
        }, 60);
      });
    });
  }, [onReady]);

  const activePage = useMemo(() => {
    return REVENUE_PAGES[activeRevenuePage] || REVENUE_PAGES.snapshot;
  }, [activeRevenuePage]);

  return (
    <div style={{ display: "grid", gap: 22 }}>
      <section
        style={{
          ...cardStyle,
          padding: "24px 24px 22px",
          overflow: "hidden",
          background:
            "radial-gradient(circle at top left, rgba(34,211,238,0.14), transparent 28%), radial-gradient(circle at top right, rgba(168,85,247,0.16), transparent 28%), rgba(15,23,42,0.82)",
        }}
      >
        <div
          style={{
            display: "flex",
            justifyContent: "space-between",
            gap: 18,
            flexWrap: "wrap",
            alignItems: "flex-start",
          }}
        >
          <div>
            <div
              style={{
                display: "inline-flex",
                alignItems: "center",
                gap: 8,
                padding: "7px 12px",
                borderRadius: 999,
                background: "rgba(59,130,246,0.12)",
                border: "1px solid rgba(147,197,253,0.18)",
                color: "#bfdbfe",
                fontSize: "0.78rem",
                fontWeight: 900,
                marginBottom: 12,
              }}
            >
              {activePage.eyebrow}
            </div>

            <h2 style={sectionTitleStyle}>
              {activePage.emoji} Revenue Overview
            </h2>

            <p style={{ ...sectionSubtextStyle, maxWidth: 820 }}>
              {activePage.subtitle}
            </p>
          </div>

          <div
            style={{
              display: "grid",
              gap: 6,
              justifyItems: "end",
              minWidth: 180,
            }}
          >
            <div
              style={{
                color: "#94a3b8",
                fontSize: "0.78rem",
                fontWeight: 900,
                textTransform: "uppercase",
                letterSpacing: "0.08em",
              }}
            >
              Active Revenue Page
            </div>

            <div
              style={{
                color: "#ffffff",
                fontSize: "1.05rem",
                fontWeight: 950,
              }}
            >
              {activePage.emoji} {activePage.title}
            </div>
          </div>
        </div>
      </section>

      <RevenueNestedMenu
        activeRevenuePage={activeRevenuePage}
        onSelectRevenuePage={setActiveRevenuePage}
      />

      {activeRevenuePage === "snapshot" ? (
        <RevenueSnapshotPage kpis={kpis} />
      ) : null}

      {activeRevenuePage === "revenue_by_volume" ? (
        <RevenueByVolumePage kpis={kpis} />
      ) : null}

      {activeRevenuePage === "revenue_by_platform" ? (
        <RevenueByPlatformPage kpis={kpis} />
      ) : null}

      {activeRevenuePage === "tax_export" ? (
        <RevenueTaxExportPage kpis={kpis} />
      ) : null}
    </div>
  );
}