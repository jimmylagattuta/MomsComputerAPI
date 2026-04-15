import React, { useMemo, useRef, useState } from "react";

const LOGO_URL =
  "https://res.cloudinary.com/djtsuktwb/image/upload/v1769703507/ChatGPT_Image_Jan_29_2026_08_00_07_AM_1_3_gtqeo8.jpg";

const sampleUsers = [
  {
    id: 1,
    initials: "JL",
    name: "James Lagattuta",
    email: "jimmy.lagattuta@gmail.com",
    role: "Admin",
    status: "Active",
    createdAt: "Apr 2026",
  },
  {
    id: 2,
    initials: "JD",
    name: "John Doe",
    email: "example@mom.com",
    role: "Senior",
    status: "Active",
    createdAt: "Apr 2026",
  },
  {
    id: 3,
    initials: "TR",
    name: "Ted Rowlend",
    email: "ted@mail.com",
    role: "Senior",
    status: "Inactive",
    createdAt: "Mar 2026",
  },
  {
    id: 4,
    initials: "BD",
    name: "Bob Doe",
    email: "me@mail.com",
    role: "Senior",
    status: "Active",
    createdAt: "Mar 2026",
  },
  {
    id: 5,
    initials: "MC",
    name: "Mom Support",
    email: "support@momscomputer.com",
    role: "Admin",
    status: "Active",
    createdAt: "Apr 2026",
  },
];

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
  const [search, setSearch] = useState("");
  const [statusFilter, setStatusFilter] = useState("All");
  const usersRef = useRef(null);

  const filteredUsers = useMemo(() => {
    return sampleUsers.filter((user) => {
      const matchesSearch =
        user.name.toLowerCase().includes(search.toLowerCase()) ||
        user.email.toLowerCase().includes(search.toLowerCase()) ||
        user.role.toLowerCase().includes(search.toLowerCase());

      const matchesStatus =
        statusFilter === "All" ? true : user.status === statusFilter;

      return matchesSearch && matchesStatus;
    });
  }, [search, statusFilter]);

  const scrollToUsers = () => {
    usersRef.current?.scrollIntoView({ behavior: "smooth", block: "start" });
  };

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
              Revenue, subscriptions, users, and account health in one clean admin view.
            </p>
          </div>
        </div>

        <button style={primaryButtonStyle} onClick={scrollToUsers}>
          View Users
        </button>
      </section>

      <section
        style={{
          display: "grid",
          gridTemplateColumns: "repeat(auto-fit, minmax(220px, 1fr))",
          gap: 18,
        }}
      >
        <StatCard
          title="MRR"
          value="--"
          subtext="Monthly recurring revenue"
          glow="rgba(34,211,238,0.18)"
        />
        <StatCard
          title="Subscriptions"
          value="--"
          subtext="Currently active subscriptions"
          glow="rgba(168,85,247,0.18)"
        />
        <StatCard
          title="Users"
          value={String(sampleUsers.length)}
          subtext="Total registered users"
          glow="rgba(244,114,182,0.18)"
        />
        <StatCard
          title="Past Due"
          value="--"
          subtext="Accounts needing attention"
          glow="rgba(250,204,21,0.16)"
        />
      </section>

      <section
        style={{
          ...cardStyle,
          display: "grid",
          gap: 16,
        }}
      >
        <div>
          <h2 style={sectionTitleStyle}>Filters</h2>
          <p style={sectionSubtextStyle}>Search and narrow the users list</p>
        </div>

        <div
          style={{
            display: "grid",
            gridTemplateColumns: "minmax(0, 1.4fr) minmax(180px, 220px)",
            gap: 14,
          }}
        >
          <input
            type="text"
            placeholder="Search by name, email, or role..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            style={inputStyle}
          />

          <select
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
            style={inputStyle}
          >
            <option value="All">All Statuses</option>
            <option value="Active">Active Only</option>
            <option value="Inactive">Inactive Only</option>
          </select>
        </div>
      </section>

      <section ref={usersRef} style={cardStyle}>
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
            <p style={sectionSubtextStyle}>
              Showing {filteredUsers.length} of {sampleUsers.length} users
            </p>
          </div>
        </div>

        <div style={{ display: "grid", gap: 12 }}>
          {filteredUsers.length > 0 ? (
            filteredUsers.map((user) => (
              <UserRow
                key={user.id}
                initials={user.initials}
                name={user.name}
                email={user.email}
                role={user.role}
                status={user.status}
                createdAt={user.createdAt}
              />
            ))
          ) : (
            <div
              style={{
                padding: "28px 20px",
                borderRadius: 18,
                background: "rgba(255,255,255,0.04)",
                border: "1px solid rgba(255,255,255,0.06)",
                color: "#cbd5e1",
                fontWeight: 700,
              }}
            >
              No users match your current filters.
            </div>
          )}
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

function UserRow({ initials, name, email, role, status, createdAt }) {
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

      <div style={{ textAlign: "right" }}>
        <div
          style={{
            padding: "7px 12px",
            borderRadius: 999,
            background: "rgba(255,255,255,0.06)",
            border: "1px solid rgba(255,255,255,0.08)",
            color: "#dbeafe",
            fontSize: "0.8rem",
            fontWeight: 700,
            display: "inline-block",
          }}
        >
          {role}
        </div>
        <div
          style={{
            color: "#94a3b8",
            fontSize: "0.82rem",
            marginTop: 6,
          }}
        >
          {createdAt}
        </div>
      </div>

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

const inputStyle = {
  width: "100%",
  padding: "14px 16px",
  borderRadius: "16px",
  border: "1px solid rgba(255,255,255,0.12)",
  background: "rgba(255,255,255,0.05)",
  color: "#ffffff",
  outline: "none",
  fontSize: "0.96rem",
  boxSizing: "border-box",
};