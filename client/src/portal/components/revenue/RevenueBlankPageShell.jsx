import React from "react";
import {
  cardStyle,
  sectionSubtextStyle,
  sectionTitleStyle,
} from "../../styles/portalStyles";

export default function RevenueBlankPageShell({
  emoji,
  title,
  subtitle,
  children,
}) {
  return (
    <section
      style={{
        ...cardStyle,
        padding: 24,
        display: "grid",
        gap: 18,
        overflow: "hidden",
        background:
          "radial-gradient(circle at top right, rgba(59,130,246,0.10), transparent 32%), rgba(15,23,42,0.78)",
      }}
    >
      <div>
        <h2 style={sectionTitleStyle}>
          {emoji} {title}
        </h2>

        <p style={{ ...sectionSubtextStyle, maxWidth: 820 }}>{subtitle}</p>
      </div>

      <div
        style={{
          display: "grid",
          gridTemplateColumns: "repeat(auto-fit, minmax(220px, 1fr))",
          gap: 14,
        }}
      >
        {children}
      </div>
    </section>
  );
}

export function RevenuePlaceholderCard({ label, value, subtext, color }) {
  return (
    <div
      style={{
        borderRadius: 20,
        padding: 18,
        background: "rgba(255,255,255,0.04)",
        border: "1px solid rgba(255,255,255,0.08)",
        minHeight: 118,
        display: "grid",
        alignContent: "space-between",
        gap: 14,
      }}
    >
      <div
        style={{
          color: "#94a3b8",
          fontSize: "0.78rem",
          fontWeight: 950,
          textTransform: "uppercase",
          letterSpacing: "0.07em",
        }}
      >
        {label}
      </div>

      <div
        style={{
          color: color || "#ffffff",
          fontSize: "1.45rem",
          fontWeight: 950,
          letterSpacing: "-0.03em",
        }}
      >
        {value}
      </div>

      <div
        style={{
          color: "#94a3b8",
          fontSize: "0.84rem",
          fontWeight: 700,
          lineHeight: 1.5,
        }}
      >
        {subtext}
      </div>
    </div>
  );
}