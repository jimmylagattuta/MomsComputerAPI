import React from "react";

const cardStyle = {
  position: "relative",
  overflow: "hidden",
  borderRadius: 24,
  padding: 24,
  background: "rgba(15, 23, 42, 0.78)",
  border: "1px solid rgba(255,255,255,0.10)",
  boxShadow: "0 20px 60px rgba(0,0,0,0.28)",
  backdropFilter: "blur(14px)",
};

const pillStyle = {
  display: "inline-flex",
  alignItems: "center",
  gap: 8,
  padding: "8px 14px",
  borderRadius: 999,
  background: "rgba(255,255,255,0.06)",
  border: "1px solid rgba(255,255,255,0.09)",
  fontSize: "0.85rem",
  fontWeight: 700,
  color: "#dbeafe",
};

const statCard = (accent) => ({
  ...cardStyle,
  minHeight: 180,
  background: `linear-gradient(180deg, rgba(15,23,42,0.88) 0%, rgba(15,23,42,0.78) 100%), ${accent}`,
});

export default function Dashboard() {
  return (
    <div style={{ display: "grid", gap: 24 }}>
      <section
        style={{
          ...cardStyle,
          padding: "34px 28px",
          background:
            "radial-gradient(circle at top right, rgba(168,85,247,0.18), transparent 28%), radial-gradient(circle at top left, rgba(34,211,238,0.18), transparent 25%), rgba(15,23,42,0.82)",
        }}
      >
        <div style={{ display: "grid", gap: 18 }}>
          <div style={pillStyle}>⚡ Live Admin Surface</div>

          <div
            style={{
              display: "grid",
              gap: 14,
              gridTemplateColumns: "minmax(0, 1.5fr) minmax(260px, 0.9fr)",
            }}
          >
            <div>
              <h2
                style={{
                  margin: 0,
                  fontSize: "clamp(2rem, 4vw, 3.4rem)",
                  lineHeight: 1.03,
                  letterSpacing: "-0.04em",
                  fontWeight: 900,
                }}
              >
                Futuristic control for users, money, support, and ops.
              </h2>

              <p
                style={{
                  margin: "16px 0 0",
                  fontSize: "1.05rem",
                  lineHeight: 1.7,
                  color: "#cbd5e1",
                  maxWidth: 760,
                }}
              >
                Your portal is officially live. Next we can wire in auth, role
                protection, financial metrics, user activity, support threads,
                subscriptions, and a much more advanced AI-styled dashboard.
              </p>
            </div>

            <div
              style={{
                borderRadius: 24,
                padding: 20,
                background: "rgba(255,255,255,0.04)",
                border: "1px solid rgba(255,255,255,0.08)",
                display: "grid",
                gap: 12,
                alignContent: "start",
              }}
            >
              <div style={{ ...pillStyle, width: "fit-content" }}>🤖 System Status</div>

              <div style={{ display: "grid", gap: 10, marginTop: 6 }}>
                <StatusRow label="Portal Route" value="Online" color="#22c55e" />
                <StatusRow label="React Build" value="Deployed" color="#38bdf8" />
                <StatusRow label="Rails Backend" value="Connected" color="#a78bfa" />
                <StatusRow label="Admin Surface" value="Scaffolded" color="#f472b6" />
              </div>
            </div>
          </div>
        </div>
      </section>

      <section
        style={{
          display: "grid",
          gridTemplateColumns: "repeat(auto-fit, minmax(240px, 1fr))",
          gap: 20,
        }}
      >
        <div style={statCard("radial-gradient(circle at top right, rgba(34,211,238,0.22), transparent 40%)")}>
          <MiniGlow color="rgba(34,211,238,0.18)" />
          <div style={pillStyle}>👤 Users</div>
          <div style={{ marginTop: 24, fontSize: "2.6rem", fontWeight: 900 }}>--</div>
          <div style={{ marginTop: 8, color: "#cbd5e1" }}>Registered users coming next</div>
        </div>

        <div style={statCard("radial-gradient(circle at top right, rgba(168,85,247,0.22), transparent 40%)")}>
          <MiniGlow color="rgba(168,85,247,0.18)" />
          <div style={pillStyle}>💸 Revenue</div>
          <div style={{ marginTop: 24, fontSize: "2.6rem", fontWeight: 900 }}>--</div>
          <div style={{ marginTop: 8, color: "#cbd5e1" }}>Financial metrics panel ready to wire</div>
        </div>

        <div style={statCard("radial-gradient(circle at top right, rgba(244,114,182,0.22), transparent 40%)")}>
          <MiniGlow color="rgba(244,114,182,0.18)" />
          <div style={pillStyle}>🛟 Support</div>
          <div style={{ marginTop: 24, fontSize: "2.6rem", fontWeight: 900 }}>--</div>
          <div style={{ marginTop: 8, color: "#cbd5e1" }}>Live support thread dashboard next</div>
        </div>

        <div style={statCard("radial-gradient(circle at top right, rgba(250,204,21,0.18), transparent 40%)")}>
          <MiniGlow color="rgba(250,204,21,0.14)" />
          <div style={pillStyle}>🧠 AI Ops</div>
          <div style={{ marginTop: 24, fontSize: "2.6rem", fontWeight: 900 }}>ACTIVE</div>
          <div style={{ marginTop: 8, color: "#cbd5e1" }}>Futuristic dashboard theme online</div>
        </div>
      </section>

      <section
        style={{
          display: "grid",
          gridTemplateColumns: "repeat(auto-fit, minmax(320px, 1fr))",
          gap: 20,
        }}
      >
        <div style={cardStyle}>
          <MiniGlow color="rgba(34,211,238,0.14)" />
          <div style={pillStyle}>🚀 Next Build Targets</div>
          <ul
            style={{
              margin: "18px 0 0",
              paddingLeft: 18,
              color: "#e2e8f0",
              lineHeight: 1.9,
            }}
          >
            <li>Admin auth with JWT login</li>
            <li>Protected routes for portal-only access</li>
            <li>Dashboard metrics from `/v1/admin/dashboard`</li>
            <li>Users table and support thread inbox</li>
            <li>Revenue, subscriptions, and tax-friendly summaries</li>
          </ul>
        </div>

        <div style={cardStyle}>
          <MiniGlow color="rgba(168,85,247,0.14)" />
          <div style={pillStyle}>🛠 Visual Direction</div>
          <p
            style={{
              margin: "18px 0 0",
              color: "#cbd5e1",
              lineHeight: 1.8,
            }}
          >
            This version gives you a neon AI command-center feel with a colorful
            robot header, glowing cards, glassy panels, gradient lighting, and a
            more premium admin presence without adding any libraries yet.
          </p>
        </div>
      </section>
    </div>
  );
}

function StatusRow({ label, value, color }) {
  return (
    <div
      style={{
        display: "flex",
        justifyContent: "space-between",
        alignItems: "center",
        gap: 12,
        padding: "12px 14px",
        borderRadius: 16,
        background: "rgba(255,255,255,0.04)",
        border: "1px solid rgba(255,255,255,0.06)",
      }}
    >
      <span style={{ color: "#cbd5e1", fontWeight: 600 }}>{label}</span>

      <span
        style={{
          display: "inline-flex",
          alignItems: "center",
          gap: 8,
          fontWeight: 800,
          color: "#ffffff",
        }}
      >
        <span
          style={{
            width: 10,
            height: 10,
            borderRadius: "50%",
            background: color,
            boxShadow: `0 0 14px ${color}`,
          }}
        />
        {value}
      </span>
    </div>
  );
}

function MiniGlow({ color }) {
  return (
    <div
      style={{
        position: "absolute",
        top: -30,
        right: -30,
        width: 120,
        height: 120,
        borderRadius: "50%",
        background: color,
        filter: "blur(30px)",
        pointerEvents: "none",
      }}
    />
  );
}