import React from "react";
import Glow from "./Glow";
import { labelStyle, statCardStyle } from "../styles/portalStyles";

export default function StatCard({ title, value, subtext, glow, onClick }) {
  const isClickable = typeof onClick === "function";

  const sharedStyle = {
    ...statCardStyle,
    width: "100%",
    textAlign: "left",
    color: "inherit",
    cursor: isClickable ? "pointer" : "default",
    transition:
      "transform 0.22s ease, border-color 0.22s ease, box-shadow 0.22s ease, background 0.22s ease",
  };

  const content = (
    <>
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
    </>
  );

  if (isClickable) {
    return (
      <>
        <button
          type="button"
          onClick={onClick}
          className="portal-stat-card-clickable"
          style={sharedStyle}
        >
          {content}
        </button>

        <style>
          {`
            .portal-stat-card-clickable:hover {
              transform: translateY(-4px);
              border-color: rgba(147,197,253,0.36) !important;
              box-shadow:
                0 24px 70px rgba(0,0,0,0.34),
                0 0 28px rgba(147,197,253,0.12) !important;
              background: rgba(15, 23, 42, 0.88) !important;
            }

            .portal-stat-card-clickable:active {
              transform: translateY(-1px);
            }

            .portal-stat-card-clickable:focus-visible {
              outline: 2px solid rgba(147,197,253,0.75);
              outline-offset: 4px;
            }
          `}
        </style>
      </>
    );
  }

  return <div style={sharedStyle}>{content}</div>;
}