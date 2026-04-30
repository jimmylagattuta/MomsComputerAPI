import React from "react";
import PortalMenuDropdown from "./PortalMenuDropdown";
import { cardStyle, labelStyle } from "../styles/portalStyles";

const LOGO_URL =
  "https://res.cloudinary.com/djtsuktwb/image/upload/v1769703507/ChatGPT_Image_Jan_29_2026_08_00_07_AM_1_3_gtqeo8.jpg";

export default function PortalHeader({
  activePanel,
  onSelectPanel,
  onLogoClick,
  onLogout,
}) {
  const handleLogoClick = () => {
    if (typeof onLogoClick === "function") {
      onLogoClick();
      return;
    }

    onSelectPanel("users");
  };

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
        overflow: "visible",
        zIndex: 1000,
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
        <button
          type="button"
          onClick={handleLogoClick}
          title="Go to main panel"
          aria-label="Go to main panel"
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
            cursor: "pointer",
            transition:
              "transform 0.22s ease, border-color 0.22s ease, box-shadow 0.22s ease, background 0.22s ease",
          }}
          onMouseEnter={(event) => {
            event.currentTarget.style.transform = "translateY(-2px)";
            event.currentTarget.style.borderColor = "rgba(147,197,253,0.28)";
            event.currentTarget.style.background = "rgba(255,255,255,0.09)";
            event.currentTarget.style.boxShadow =
              "0 16px 44px rgba(0,0,0,0.34), 0 0 22px rgba(147,197,253,0.10)";
          }}
          onMouseLeave={(event) => {
            event.currentTarget.style.transform = "translateY(0)";
            event.currentTarget.style.borderColor = "rgba(255,255,255,0.10)";
            event.currentTarget.style.background = "rgba(255,255,255,0.06)";
            event.currentTarget.style.boxShadow = "0 12px 40px rgba(0,0,0,0.28)";
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
              pointerEvents: "none",
            }}
          />
        </button>

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