import React from "react";
import Glow from "./Glow";
import {
  cardStyle,
  sectionSubtextStyle,
  sectionTitleStyle,
} from "../styles/portalStyles";

export default function BillingDebugPanel({
  kpis,
  kpisLoading,
  kpisError,
  displayMrrCents,
  displaySubscribers,
}) {
  return (
    <section style={cardStyle}>
      <Glow color="rgba(34,211,238,0.10)" />

      <div>
        <h2 style={sectionTitleStyle}>Billing KPI Debug</h2>
        <p style={sectionSubtextStyle}>
          Temporary console/debug view for backend portal data.
        </p>
      </div>

      <pre
        style={{
          margin: "16px 0 0",
          padding: 16,
          borderRadius: 16,
          background: "rgba(0,0,0,0.28)",
          border: "1px solid rgba(255,255,255,0.08)",
          color: "#dbeafe",
          fontSize: "0.82rem",
          lineHeight: 1.55,
          overflowX: "auto",
          whiteSpace: "pre-wrap",
        }}
      >
        {JSON.stringify(
          {
            kpisLoading,
            kpisError,
            displayMrrCents,
            displaySubscribers,
            kpis,
          },
          null,
          2
        )}
      </pre>
    </section>
  );
}