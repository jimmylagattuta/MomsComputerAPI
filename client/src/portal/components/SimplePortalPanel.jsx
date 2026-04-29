import React from "react";
import Glow from "./Glow";
import {
  cardStyle,
  sectionSubtextStyle,
  sectionTitleStyle,
} from "../styles/portalStyles";

export default function SimplePortalPanel({ title, subtitle, body }) {
  return (
    <section style={cardStyle}>
      <Glow color="rgba(147,197,253,0.12)" />

      <div>
        <h2 style={sectionTitleStyle}>{title}</h2>
        <p style={sectionSubtextStyle}>{subtitle}</p>
      </div>

      <div
        style={{
          marginTop: 18,
          padding: 18,
          borderRadius: 18,
          background: "rgba(255,255,255,0.04)",
          border: "1px solid rgba(255,255,255,0.08)",
          color: "#dbeafe",
          fontSize: "0.95rem",
          fontWeight: 700,
          lineHeight: 1.7,
        }}
      >
        {body}
      </div>
    </section>
  );
}