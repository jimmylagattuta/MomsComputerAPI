import React from "react";

export default function Login() {
  return (
    <div
      style={{
        minHeight: "60vh",
        display: "grid",
        placeItems: "center",
      }}
    >
      <div
        style={{
          width: "100%",
          maxWidth: 520,
          borderRadius: 28,
          padding: 30,
          background:
            "radial-gradient(circle at top right, rgba(168,85,247,0.16), transparent 24%), radial-gradient(circle at top left, rgba(34,211,238,0.16), transparent 26%), rgba(15,23,42,0.82)",
          border: "1px solid rgba(255,255,255,0.10)",
          boxShadow: "0 25px 70px rgba(0,0,0,0.32)",
          backdropFilter: "blur(14px)",
        }}
      >
        <div
          style={{
            display: "inline-flex",
            alignItems: "center",
            gap: 8,
            padding: "8px 14px",
            borderRadius: 999,
            background: "rgba(255,255,255,0.06)",
            border: "1px solid rgba(255,255,255,0.08)",
            fontSize: "0.82rem",
            fontWeight: 800,
            color: "#67e8f9",
          }}
        >
          🤖 Secure Admin Access
        </div>

        <h2
          style={{
            margin: "18px 0 10px",
            fontSize: "2.1rem",
            fontWeight: 900,
            letterSpacing: "-0.03em",
          }}
        >
          Portal Login
        </h2>

        <p style={{ margin: 0, color: "#cbd5e1", lineHeight: 1.7 }}>
          Next step is wiring this form into your existing
          <strong> /v1/auth/login </strong>
          endpoint and protecting the portal for admin-only access.
        </p>

        <div style={{ display: "grid", gap: 14, marginTop: 24 }}>
          <input
            type="email"
            placeholder="Admin email"
            style={inputStyle}
          />
          <input
            type="password"
            placeholder="Password"
            style={inputStyle}
          />

          <button style={buttonStyle}>
            Enter Portal
          </button>
        </div>
      </div>
    </div>
  );
}

const inputStyle = {
  width: "100%",
  padding: "15px 16px",
  borderRadius: 16,
  border: "1px solid rgba(255,255,255,0.12)",
  background: "rgba(255,255,255,0.05)",
  color: "#ffffff",
  outline: "none",
  fontSize: "1rem",
  boxSizing: "border-box",
};

const buttonStyle = {
  marginTop: 4,
  border: "none",
  borderRadius: 16,
  padding: "15px 18px",
  fontWeight: 900,
  fontSize: "1rem",
  cursor: "pointer",
  color: "#081120",
  background: "linear-gradient(135deg, #67e8f9 0%, #a78bfa 50%, #f472b6 100%)",
  boxShadow: "0 16px 34px rgba(103,232,249,0.20)",
};