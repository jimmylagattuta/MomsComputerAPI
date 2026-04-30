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
  subscribers: {
    eyebrow: "Current Menu",
    title: "Subscribers",
    subtitle:
      "Review active subscribers, products, platforms, renewal windows, and subscription status.",
    emoji: "✅",
  },
  revenue_overview: {
    eyebrow: "Current Menu",
    title: "Revenue Overview",
    subtitle:
      "Review MRR, monthly revenue, yearly revenue, total revenue, and subscription performance.",
    emoji: "📊",
  },
  transactions: {
    eyebrow: "Current Menu",
    title: "Transaction Table",
    subtitle:
      "Review subscription purchases, renewals, and RevenueCat-backed payment records.",
    emoji: "💳",
  },
  revenue_by_platform: {
    eyebrow: "Current Menu",
    title: "Revenue by Platform",
    subtitle: "Compare App Store, Play Store, and platform-specific revenue totals.",
    emoji: "📱",
  },
  revenue_by_product: {
    eyebrow: "Current Menu",
    title: "Revenue by Product",
    subtitle: "Compare monthly, yearly, and product-level revenue performance.",
    emoji: "📦",
  },
  lifetime_value: {
    eyebrow: "Current Menu",
    title: "Lifetime Value",
    subtitle: "Review revenue per user and identify the highest-value customers.",
    emoji: "💎",
  },
  billing_issues: {
    eyebrow: "Current Menu",
    title: "Billing Issues",
    subtitle: "Find users with failed renewals, payment problems, or billing-risk status.",
    emoji: "⚠️",
  },
  cancelled: {
    eyebrow: "Current Menu",
    title: "Cancelled Users",
    subtitle:
      "Review users who cancelled but may still have access until the current period ends.",
    emoji: "🛑",
  },
  expired: {
    eyebrow: "Current Menu",
    title: "Expired Users",
    subtitle: "Review users whose subscription access has ended.",
    emoji: "⌛",
  },
  trials: {
    eyebrow: "Current Menu",
    title: "Trials",
    subtitle: "Review trial users, trial windows, and trial-to-paid conversion signals.",
    emoji: "🧪",
  },
  events: {
    eyebrow: "Current Menu",
    title: "Recent Events",
    subtitle: "Audit RevenueCat webhook events and subscription lifecycle activity.",
    emoji: "⚡",
  },
  webhook_audit: {
    eyebrow: "Current Menu",
    title: "Webhook Audit Log",
    subtitle:
      "Review raw RevenueCat webhook history for debugging, replaying, and audit trails.",
    emoji: "🧾",
  },
  debug: {
    eyebrow: "Current Menu",
    title: "Billing Debug",
    subtitle: "Inspect raw KPI data coming back from the backend.",
    emoji: "🔧",
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