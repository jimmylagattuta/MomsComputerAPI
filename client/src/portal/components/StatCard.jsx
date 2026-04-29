import React from "react";
import Glow from "./Glow";
import { labelStyle, statCardStyle } from "../styles/portalStyles";

export default function StatCard({ title, value, subtext, glow }) {
  return (
    <div style={statCardStyle}>
      <Glow color={glow} />

      <div>
        <div style={labelStyle}>{title}</div>

        <div
          style={{
            marginTop: 20,
            fontSize: "2.3rem",
            fontWeight: 900,
            letterSpacing: "-0.04em",
            color: "#ffffff",
          }}
        >
          {value}
        </div>
      </div>

      <div
        style={{
          marginTop: 10,
          color: "#cbd5e1",
          fontSize: "0.95rem",
        }}
      >
        {subtext}
      </div>
    </div>
  );
}