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
    subtitle:
      "Compare App Store, Play Store, and platform-specific revenue totals.",
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
    subtitle:
      "Find users with failed renewals, payment problems, or billing-risk status.",
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
    subtitle:
      "Review trial users, trial windows, and trial-to-paid conversion signals.",
    emoji: "🧪",
  },
  events: {
    eyebrow: "Current Menu",
    title: "Recent Events",
    subtitle:
      "Audit RevenueCat webhook events and subscription lifecycle activity.",
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

const glowingMenuCardStyle = {
  ...cardStyle,
  padding: "20px 22px",
  display: "flex",
  alignItems: "center",
  justifyContent: "space-between",
  gap: 14,
  flexWrap: "wrap",
  position: "relative",
  overflow: "hidden",
  border: "1px solid rgba(103,232,249,0.38)",
  background:
    "radial-gradient(circle at top left, rgba(34,211,238,0.24), transparent 26%), radial-gradient(circle at top right, rgba(168,85,247,0.22), transparent 30%), linear-gradient(135deg, rgba(15,23,42,0.96), rgba(30,41,59,0.78), rgba(49,46,129,0.56))",
  boxShadow:
    "0 0 0 1px rgba(103,232,249,0.10), 0 20px 48px rgba(0,0,0,0.36), 0 0 38px rgba(103,232,249,0.16), inset 0 1px 0 rgba(255,255,255,0.06)",
};

const currentMenuGlowStyle = {
  display: "inline-flex",
  alignItems: "center",
  justifyContent: "center",
  gap: 8,
  padding: "10px 16px",
  borderRadius: 16,
  border: "1px solid rgba(103,232,249,0.52)",
  background:
    "linear-gradient(135deg, rgba(34,211,238,0.34), rgba(96,165,250,0.28), rgba(168,85,247,0.30))",
  color: "#ffffff",
  fontWeight: 950,
  fontSize: "0.84rem",
  letterSpacing: "0.01em",
  boxShadow:
    "0 0 0 1px rgba(103,232,249,0.12), 0 18px 44px rgba(0,0,0,0.46), 0 0 34px rgba(103,232,249,0.22)",
  backdropFilter: "blur(16px)",
  WebkitBackdropFilter: "blur(16px)",
  marginBottom: 12,
  textShadow: "0 1px 8px rgba(255,255,255,0.12)",
};

const softGlowOrbStyle = {
  position: "absolute",
  right: -80,
  top: -80,
  width: 220,
  height: 220,
  borderRadius: "50%",
  background: "rgba(103,232,249,0.12)",
  filter: "blur(4px)",
  pointerEvents: "none",
};

const purpleGlowOrbStyle = {
  position: "absolute",
  left: "42%",
  bottom: -120,
  width: 260,
  height: 260,
  borderRadius: "50%",
  background: "rgba(168,85,247,0.12)",
  filter: "blur(5px)",
  pointerEvents: "none",
};

export default function ActivePanelHeader({ activePanel }) {
  const panel = useMemo(() => {
    return PANEL_LABELS[activePanel] || PANEL_LABELS.users;
  }, [activePanel]);

  return (
    <section style={glowingMenuCardStyle}>
      <div style={softGlowOrbStyle} />
      <div style={purpleGlowOrbStyle} />

      <div style={{ position: "relative", zIndex: 1 }}>
        <div style={currentMenuGlowStyle}>{panel.eyebrow}</div>

        <h2
          style={{
            ...sectionTitleStyle,
            color: "#ffffff",
            textShadow: "0 0 18px rgba(103,232,249,0.14)",
          }}
        >
          {panel.emoji} {panel.title}
        </h2>

        <p
          style={{
            ...sectionSubtextStyle,
            color: "#dbeafe",
          }}
        >
          {panel.subtitle}
        </p>
      </div>
    </section>
  );
}