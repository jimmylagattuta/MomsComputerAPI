import React, { useMemo } from "react";
import {
  cardStyle,
  sectionSubtextStyle,
  sectionTitleStyle,
} from "../styles/portalStyles";

const PANEL_LABELS = {
  users: {
    eyebrow: "Current Menu",
    title: "Users",
    subtitle: "Search users, open profiles, and review account details.",
    emoji: "👥",
  },
  transactions: {
    eyebrow: "Current Menu",
    title: "Transaction Table",
    subtitle:
      "Review subscription purchases, renewals, and RevenueCat-backed payment records.",
    emoji: "💳",
  },
  subscribers: {
    eyebrow: "Current Menu",
    title: "Subscribers",
    subtitle:
      "Review subscription status, billing state, products, platforms, and renewals.",
    emoji: "✅",
  },
  events: {
    eyebrow: "Current Menu",
    title: "Recent Events",
    subtitle: "Audit RevenueCat webhook events and subscription lifecycle activity.",
    emoji: "⚡",
  },
  debug: {
    eyebrow: "Current Menu",
    title: "Billing Debug",
    subtitle: "Inspect raw KPI data coming back from the backend.",
    emoji: "🧪",
  },
  overview: {
    eyebrow: "Current Menu",
    title: "Users",
    subtitle: "Search users, open profiles, and review account details.",
    emoji: "👥",
  },
};

export default function ActivePanelHeader({ activePanel }) {
  const panel = useMemo(() => {
    return PANEL_LABELS[activePanel] || PANEL_LABELS.users;
  }, [activePanel]);

  return (
    <section
      style={{
        ...cardStyle,
        padding: "18px 20px",
        display: "flex",
        alignItems: "center",
        justifyContent: "space-between",
        gap: 14,
        flexWrap: "wrap",
      }}
    >
      <div>
        <div
          style={{
            display: "inline-flex",
            alignItems: "center",
            gap: 8,
            padding: "6px 11px",
            borderRadius: 999,
            background: "rgba(59,130,246,0.12)",
            border: "1px solid rgba(147,197,253,0.18)",
            color: "#bfdbfe",
            fontSize: "0.78rem",
            fontWeight: 900,
            marginBottom: 10,
          }}
        >
          {panel.eyebrow}
        </div>

        <h2 style={sectionTitleStyle}>
          {panel.emoji} {panel.title}
        </h2>

        <p style={sectionSubtextStyle}>{panel.subtitle}</p>
      </div>
    </section>
  );
}