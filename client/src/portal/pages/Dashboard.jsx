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

const statCardStyle = {
  ...cardStyle,
  minHeight: 150,
  display: "flex",
  flexDirection: "column",
  justifyContent: "space-between",
};

const labelStyle = {
  display: "inline-flex",
  alignItems: "center",
  gap: 8,
  padding: "8px 14px",
  borderRadius: 999,
  background: "rgba(255,255,255,0.06)",
  border: "1px solid rgba(255,255,255,0.09)",
  fontSize: "0.82rem",
  fontWeight: 700,
  color: "#dbeafe",
  width: "fit-content",
};

const sectionTitleStyle = {
  margin: 0,
  fontSize: "1.15rem",
  fontWeight: 800,
  letterSpacing: "-0.02em",
  color: "#ffffff",
};

export default function Dashboard() {
  return (
    <div style={{ display: "grid", gap: 24 }}>
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
            Mom&apos;s Computer Dashboard
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
            A clean admin view for users, subscriptions, support, and recent activity.
          </p>
        </div>

        <div style={{ display: "flex", gap: 12, flexWrap: "wrap" }}>
          <button style={secondaryButtonStyle}>Search</button>
          <button style={primaryButtonStyle}>Add User</button>
        </div>
      </section>

      <section
        style={{
          display: "grid",
          gridTemplateColumns: "repeat(auto-fit, minmax(220px, 1fr))",
          gap: 18,
        }}
      >
        <StatCard
          title="Users"
          value="--"
          subtext="Total registered users"
          glow="rgba(34,211,238,0.18)"
        />
        <StatCard
          title="Subscriptions"
          value="--"
          subtext="Active billing accounts"
          glow="rgba(168,85,247,0.18)"
        />
        <StatCard
          title="Revenue"
          value="--"
          subtext="Monthly recurring revenue"
          glow="rgba(244,114,182,0.18)"
        />
        <StatCard
          title="Support"
          value="--"
          subtext="Open support conversations"
          glow="rgba(250,204,21,0.16)"
        />
      </section>

      <section
        style={{
          display: "grid",
          gridTemplateColumns: "minmax(0, 1.7fr) minmax(320px, 1fr)",
          gap: 20,
        }}
      >
        <div style={cardStyle}>
          <Glow color="rgba(34,211,238,0.12)" />
          <div
            style={{
              display: "flex",
              justifyContent: "space-between",
              alignItems: "center",
              gap: 14,
              flexWrap: "wrap",
              marginBottom: 18,
            }}
          >
            <div>
              <h2 style={sectionTitleStyle}>Users</h2>
              <p style={sectionSubtextStyle}>Recent accounts and quick actions</p>
            </div>

            <button style={smallButtonStyle}>View All</button>
          </div>

          <div style={{ display: "grid", gap: 12 }}>
            <UserRow
              initials="JL"
              name="James Lagattuta"
              email="jimmy.lagattuta@gmail.com"
              role="Admin"
              status="Active"
            />
            <UserRow
              initials="JD"
              name="John Doe"
              email="example@mom.com"
              role="Senior"
              status="Active"
            />
            <UserRow
              initials="TR"
              name="Ted Rowlend"
              email="ted@mail.com"
              role="Senior"
              status="Inactive"
            />
          </div>
        </div>

        <div style={{ display: "grid", gap: 20 }}>
          <div style={cardStyle}>
            <Glow color="rgba(168,85,247,0.12)" />
            <h2 style={sectionTitleStyle}>Support Threads</h2>
            <p style={sectionSubtextStyle}>Recent conversations needing attention</p>

            <div style={{ display: "grid", gap: 12, marginTop: 18 }}>
              <MiniItem
                title="Billing question"
                meta="2 unread messages"
                badge="Open"
              />
              <MiniItem
                title="Password reset help"
                meta="Waiting on reply"
                badge="Pending"
              />
              <MiniItem
                title="Tech support request"
                meta="Assigned to admin"
                badge="Open"
              />
            </div>
          </div>

          <div style={cardStyle}>
            <Glow color="rgba(244,114,182,0.12)" />
            <h2 style={sectionTitleStyle}>Recent Activity</h2>
            <p style={sectionSubtextStyle}>Latest portal and account events</p>

            <div style={{ display: "grid", gap: 12, marginTop: 18 }}>
              <ActivityItem text="New user signed up" time="Today" />
              <ActivityItem text="Support thread updated" time="Today" />
              <ActivityItem text="Subscription changed" time="Yesterday" />
              <ActivityItem text="Admin login detected" time="Yesterday" />
            </div>
          </div>
        </div>
      </section>
    </div>
  );
}

function StatCard({ title, value, subtext, glow }) {
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

function UserRow({ initials, name, email, role, status }) {
  const isActive = status === "Active";

  return (
    <div
      style={{
        display: "grid",
        gridTemplateColumns: "auto 1fr auto auto",
        gap: 14,
        alignItems: "center",
        padding: "14px 16px",
        borderRadius: 18,
        background: "rgba(255,255,255,0.04)",
        border: "1px solid rgba(255,255,255,0.06)",
      }}
    >
      <div
        style={{
          width: 44,
          height: 44,
          borderRadius: "50%",
          display: "grid",
          placeItems: "center",
          fontWeight: 900,
          color: "#081120",
          background: "linear-gradient(135deg, #67e8f9 0%, #a78bfa 100%)",
        }}
      >
        {initials}
      </div>

      <div style={{ minWidth: 0 }}>
        <div
          style={{
            fontWeight: 800,
            color: "#ffffff",
            whiteSpace: "nowrap",
            overflow: "hidden",
            textOverflow: "ellipsis",
          }}
        >
          {name}
        </div>
        <div
          style={{
            color: "#94a3b8",
            fontSize: "0.92rem",
            whiteSpace: "nowrap",
            overflow: "hidden",
            textOverflow: "ellipsis",
            marginTop: 2,
          }}
        >
          {email}
        </div>
      </div>

      <span
        style={{
          padding: "7px 12px",
          borderRadius: 999,
          background: "rgba(255,255,255,0.06)",
          border: "1px solid rgba(255,255,255,0.08)",
          color: "#dbeafe",
          fontSize: "0.8rem",
          fontWeight: 700,
        }}
      >
        {role}
      </span>

      <span
        style={{
          padding: "7px 12px",
          borderRadius: 999,
          background: isActive ? "rgba(34,197,94,0.14)" : "rgba(239,68,68,0.14)",
          border: isActive
            ? "1px solid rgba(34,197,94,0.28)"
            : "1px solid rgba(239,68,68,0.28)",
          color: isActive ? "#86efac" : "#fca5a5",
          fontSize: "0.8rem",
          fontWeight: 800,
        }}
      >
        {status}
      </span>
    </div>
  );
}

function MiniItem({ title, meta, badge }) {
  return (
    <div
      style={{
        padding: "14px 16px",
        borderRadius: 18,
        background: "rgba(255,255,255,0.04)",
        border: "1px solid rgba(255,255,255,0.06)",
        display: "flex",
        justifyContent: "space-between",
        alignItems: "center",
        gap: 12,
      }}
    >
      <div>
        <div style={{ color: "#ffffff", fontWeight: 800 }}>{title}</div>
        <div style={{ color: "#94a3b8", fontSize: "0.9rem", marginTop: 3 }}>{meta}</div>
      </div>

      <span
        style={{
          padding: "7px 12px",
          borderRadius: 999,
          background: "rgba(255,255,255,0.06)",
          border: "1px solid rgba(255,255,255,0.08)",
          color: "#dbeafe",
          fontSize: "0.78rem",
          fontWeight: 800,
          whiteSpace: "nowrap",
        }}
      >
        {badge}
      </span>
    </div>
  );
}

function ActivityItem({ text, time }) {
  return (
    <div
      style={{
        display: "flex",
        justifyContent: "space-between",
        alignItems: "center",
        gap: 12,
        padding: "12px 0",
        borderBottom: "1px solid rgba(255,255,255,0.06)",
      }}
    >
      <span style={{ color: "#e2e8f0", fontWeight: 600 }}>{text}</span>
      <span style={{ color: "#94a3b8", fontSize: "0.88rem", whiteSpace: "nowrap" }}>
        {time}
      </span>
    </div>
  );
}

function Glow({ color }) {
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

const sectionSubtextStyle = {
  margin: "6px 0 0",
  color: "#94a3b8",
  fontSize: "0.95rem",
};

const primaryButtonStyle = {
  border: "none",
  borderRadius: 14,
  padding: "12px 18px",
  fontWeight: 900,
  fontSize: "0.95rem",
  cursor: "pointer",
  color: "#081120",
  background: "linear-gradient(135deg, #67e8f9 0%, #a78bfa 50%, #f472b6 100%)",
  boxShadow: "0 16px 34px rgba(103,232,249,0.20)",
};

const secondaryButtonStyle = {
  border: "1px solid rgba(255,255,255,0.10)",
  borderRadius: 14,
  padding: "12px 18px",
  fontWeight: 800,
  fontSize: "0.95rem",
  cursor: "pointer",
  color: "#e2e8f0",
  background: "rgba(255,255,255,0.05)",
};

const smallButtonStyle = {
  border: "1px solid rgba(255,255,255,0.10)",
  borderRadius: 12,
  padding: "10px 14px",
  fontWeight: 800,
  fontSize: "0.88rem",
  cursor: "pointer",
  color: "#e2e8f0",
  background: "rgba(255,255,255,0.05)",
};