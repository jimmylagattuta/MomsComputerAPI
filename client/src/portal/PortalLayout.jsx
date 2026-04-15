import React from "react";
import { Outlet, NavLink } from "react-router-dom";

const linkBaseStyle = {
  textDecoration: "none",
  padding: "10px 16px",
  borderRadius: "999px",
  fontWeight: 700,
  fontSize: "0.95rem",
  transition: "all 0.2s ease",
  border: "1px solid rgba(255,255,255,0.12)",
};

export default function PortalLayout() {
  const navLinkStyle = ({ isActive }) => ({
    ...linkBaseStyle,
    color: isActive ? "#081120" : "#dbeafe",
    background: isActive
      ? "linear-gradient(135deg, #67e8f9 0%, #a78bfa 50%, #f472b6 100%)"
      : "rgba(255,255,255,0.06)",
    boxShadow: isActive
      ? "0 8px 30px rgba(103,232,249,0.25)"
      : "0 4px 18px rgba(0,0,0,0.18)",
  });

  return (
    <div
      style={{
        minHeight: "100vh",
        color: "#ffffff",
        background:
          "radial-gradient(circle at top left, rgba(34,211,238,0.20), transparent 28%), radial-gradient(circle at top right, rgba(168,85,247,0.18), transparent 30%), radial-gradient(circle at bottom center, rgba(244,114,182,0.16), transparent 34%), linear-gradient(180deg, #020617 0%, #081225 38%, #0b1020 100%)",
        position: "relative",
        overflow: "hidden",
      }}
    >
      <div
        style={{
          position: "absolute",
          inset: 0,
          backgroundImage:
            "linear-gradient(rgba(255,255,255,0.035) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.035) 1px, transparent 1px)",
          backgroundSize: "32px 32px",
          maskImage: "linear-gradient(to bottom, rgba(0,0,0,0.8), rgba(0,0,0,0.25))",
          pointerEvents: "none",
        }}
      />

      <div
        style={{
          position: "absolute",
          top: -120,
          left: -80,
          width: 260,
          height: 260,
          borderRadius: "50%",
          background: "rgba(34,211,238,0.12)",
          filter: "blur(40px)",
          pointerEvents: "none",
        }}
      />

      <div
        style={{
          position: "absolute",
          top: 40,
          right: -60,
          width: 260,
          height: 260,
          borderRadius: "50%",
          background: "rgba(168,85,247,0.16)",
          filter: "blur(50px)",
          pointerEvents: "none",
        }}
      />

      <header
        style={{
          position: "sticky",
          top: 0,
          zIndex: 10,
          backdropFilter: "blur(16px)",
          background: "rgba(2, 6, 23, 0.68)",
          borderBottom: "1px solid rgba(255,255,255,0.08)",
          boxShadow: "0 10px 40px rgba(0,0,0,0.22)",
        }}
      >
        <div
          style={{
            maxWidth: 1400,
            margin: "0 auto",
            padding: "22px 24px",
            display: "flex",
            justifyContent: "space-between",
            alignItems: "center",
            gap: 20,
            flexWrap: "wrap",
          }}
        >
          <div style={{ display: "flex", alignItems: "center", gap: 16 }}>
            <div
              style={{
                width: 58,
                height: 58,
                borderRadius: 18,
                display: "grid",
                placeItems: "center",
                fontSize: 28,
                background:
                  "linear-gradient(135deg, rgba(34,211,238,0.95), rgba(168,85,247,0.95) 55%, rgba(244,114,182,0.95))",
                color: "#081120",
                boxShadow:
                  "0 0 0 1px rgba(255,255,255,0.08), 0 14px 34px rgba(34,211,238,0.22)",
              }}
            >
              🤖
            </div>

            <div>
              <div
                style={{
                  fontSize: "0.78rem",
                  letterSpacing: "0.22em",
                  textTransform: "uppercase",
                  color: "#67e8f9",
                  marginBottom: 6,
                  fontWeight: 800,
                }}
              >
                AI Control Center
              </div>

              <h1
                style={{
                  margin: 0,
                  fontSize: "clamp(1.8rem, 2.6vw, 2.6rem)",
                  lineHeight: 1,
                  fontWeight: 900,
                  letterSpacing: "-0.03em",
                }}
              >
                Mom&apos;s Computer Portal
              </h1>
            </div>
          </div>

          <nav style={{ display: "flex", gap: 12, flexWrap: "wrap" }}>
            <NavLink to="/" end style={navLinkStyle}>
              Dashboard
            </NavLink>
            <NavLink to="/login" style={navLinkStyle}>
              Admin Login
            </NavLink>
          </nav>
        </div>
      </header>

      <main
        style={{
          position: "relative",
          zIndex: 1,
          maxWidth: 1400,
          margin: "0 auto",
          padding: "36px 24px 64px",
        }}
      >
        <Outlet />
      </main>
    </div>
  );
}