import React from "react";
import PortalMenuDropdown from "./PortalMenuDropdown";
import { cardStyle, labelStyle } from "../styles/portalStyles";

const LOGO_URL =
  "https://res.cloudinary.com/djtsuktwb/image/upload/v1769703507/ChatGPT_Image_Jan_29_2026_08_00_07_AM_1_3_gtqeo8.jpg";

export default function PortalHeader({ activePanel, onSelectPanel, onLogout }) {
  return (
    <section
      style={{
        ...cardStyle,
        padding: "28px 24px",
        display: "flex",
        justifyContent: "space-between",
        alignItems: "center",
        gap: 18,
        flexWrap: "wrap",
      }}
    >
      <div
        style={{
          display: "flex",
          alignItems: "center",
          gap: 18,
          flexWrap: "wrap",
        }}
      >
        <div
          style={{
            width: 70,
            height: 70,
            borderRadius: 20,
            padding: 8,
            background: "rgba(255,255,255,0.06)",
            border: "1px solid rgba(255,255,255,0.10)",
            boxShadow: "0 12px 40px rgba(0,0,0,0.28)",
            display: "grid",
            placeItems: "center",
            flexShrink: 0,
          }}
        >
          <img
            src={LOGO_URL}
            alt="Mom's Computer logo"
            style={{
              width: "100%",
              height: "100%",
              objectFit: "contain",
              borderRadius: 14,
              display: "block",
            }}
          />
        </div>

        <div>
          <div style={{ ...labelStyle, marginBottom: 14 }}>Admin Portal</div>

          <h1
            style={{
              margin: 0,
              fontSize: "clamp(1.9rem, 3vw, 2.8rem)",
              fontWeight: 900,
              letterSpacing: "-0.04em",
              lineHeight: 1.05,
              color: "#ffffff",
            }}
          >
            Mom&apos;s Computer AI App
            <br />
            Dashboard
          </h1>

          <p
            style={{
              margin: "10px 0 0",
              color: "#cbd5e1",
              fontSize: "1rem",
              lineHeight: 1.7,
              maxWidth: 700,
            }}
          >
            Revenue, subscriptions, users, transactions, and account health in one clean admin view.
          </p>
        </div>
      </div>

      <PortalMenuDropdown
        activePanel={activePanel}
        onSelectPanel={onSelectPanel}
        onLogout={onLogout}
      />
    </section>
  );
}