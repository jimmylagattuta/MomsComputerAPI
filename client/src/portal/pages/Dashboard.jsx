import React, { useEffect, useMemo, useState } from "react";

const LOGO_URL =
  "https://res.cloudinary.com/djtsuktwb/image/upload/v1769703507/ChatGPT_Image_Jan_29_2026_08_00_07_AM_1_3_gtqeo8.jpg";

const USERS_PER_PAGE = 25;

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

const sectionSubtextStyle = {
  margin: "6px 0 0",
  color: "#94a3b8",
  fontSize: "0.95rem",
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

const pageButtonStyle = {
  border: "1px solid rgba(255,255,255,0.10)",
  borderRadius: 12,
  minWidth: 44,
  height: 44,
  padding: 0,
  fontWeight: 900,
  fontSize: "1rem",
  color: "#e2e8f0",
  background: "rgba(255,255,255,0.05)",
};

const pageIndicatorStyle = {
  padding: "10px 14px",
  borderRadius: 12,
  border: "1px solid rgba(255,255,255,0.08)",
  background: "rgba(255,255,255,0.04)",
  color: "#cbd5e1",
  fontSize: "0.9rem",
  fontWeight: 700,
};

const emptyStateStyle = {
  padding: "28px 20px",
  borderRadius: 18,
  background: "rgba(255,255,255,0.04)",
  border: "1px solid rgba(255,255,255,0.06)",
  color: "#cbd5e1",
  fontWeight: 700,
};

const errorStateStyle = {
  padding: "28px 20px",
  borderRadius: 18,
  background: "rgba(239,68,68,0.12)",
  border: "1px solid rgba(248,113,113,0.25)",
  color: "#fecaca",
  fontWeight: 700,
};

const infoGridStyle = {
  display: "grid",
  gap: 2,
};

const backButtonStyle = {
  width: "fit-content",
  padding: "10px 14px",
  borderRadius: 12,
  border: "1px solid rgba(147,197,253,0.22)",
  background: "rgba(59,130,246,0.08)",
  color: "#93c5fd",
  fontWeight: 800,
  cursor: "pointer",
};

export default function Dashboard() {
  const [users, setUsers] = useState([]);
  const [usersLoading, setUsersLoading] = useState(true);
  const [usersError, setUsersError] = useState("");

  const [search, setSearch] = useState("");
  const [statusFilter, setStatusFilter] = useState("All");
  const [currentPage, setCurrentPage] = useState(1);
  const [selectedUserId, setSelectedUserId] = useState(null);

  useEffect(() => {
    const loadUsers = async () => {
      try {
        setUsersLoading(true);
        setUsersError("");

        const token = localStorage.getItem("portalToken");

        const response = await fetch("/v1/admin/users", {
          method: "GET",
          headers: {
            "Content-Type": "application/json",
            ...(token ? { Authorization: `Bearer ${token}` } : {}),
          },
        });

        let data = null;
        try {
          data = await response.json();
        } catch (_err) {
          data = null;
        }

        if (!response.ok) {
          throw new Error(data?.message || data?.error || "Failed to load users.");
        }

        const normalizedUsers = Array.isArray(data)
          ? data
          : Array.isArray(data?.users)
          ? data.users
          : [];

        setUsers(normalizedUsers);
      } catch (err) {
        setUsers([]);
        setUsersError(err.message || "Failed to load users.");
      } finally {
        setUsersLoading(false);
      }
    };

    loadUsers();
  }, []);

  const filteredUsers = useMemo(() => {
    return users.filter((user) => {
      const fullName = `${user.first_name || ""} ${user.last_name || ""}`.trim();
      const email = user.email || "";
      const role = user.role || "";
      const normalizedStatus =
        String(user.status || "").toLowerCase() === "active" ? "Active" : "Inactive";

      const matchesSearch =
        fullName.toLowerCase().includes(search.toLowerCase()) ||
        email.toLowerCase().includes(search.toLowerCase()) ||
        role.toLowerCase().includes(search.toLowerCase());

      const matchesStatus =
        statusFilter === "All" ? true : normalizedStatus === statusFilter;

      return matchesSearch && matchesStatus;
    });
  }, [users, search, statusFilter]);

  const totalPages = Math.max(1, Math.ceil(filteredUsers.length / USERS_PER_PAGE));

  const paginatedUsers = useMemo(() => {
    const startIndex = (currentPage - 1) * USERS_PER_PAGE;
    return filteredUsers.slice(startIndex, startIndex + USERS_PER_PAGE);
  }, [filteredUsers, currentPage]);

  useEffect(() => {
    setCurrentPage(1);
  }, [search, statusFilter]);

  useEffect(() => {
    if (currentPage > totalPages) {
      setCurrentPage(totalPages);
    }
  }, [currentPage, totalPages]);

  const firstUserIndex =
    filteredUsers.length === 0 ? 0 : (currentPage - 1) * USERS_PER_PAGE + 1;
  const lastUserIndex = Math.min(currentPage * USERS_PER_PAGE, filteredUsers.length);

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
          value={usersLoading ? "..." : String(users.length)}
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

      {selectedUserId ? (
        <EmbeddedUserDetail
          userId={selectedUserId}
          onBack={() => setSelectedUserId(null)}
        />
      ) : (
        <>
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

          <section style={cardStyle}>
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
                  Showing {firstUserIndex}-{lastUserIndex} of {filteredUsers.length} users
                </p>
              </div>

              <div
                style={{
                  display: "flex",
                  alignItems: "center",
                  gap: 10,
                }}
              >
                <button
                  type="button"
                  onClick={() => setCurrentPage((prev) => Math.max(1, prev - 1))}
                  disabled={currentPage === 1}
                  style={{
                    ...pageButtonStyle,
                    opacity: currentPage === 1 ? 0.45 : 1,
                    cursor: currentPage === 1 ? "not-allowed" : "pointer",
                  }}
                >
                  ←
                </button>

                <div style={pageIndicatorStyle}>
                  Page {currentPage} of {totalPages}
                </div>

                <button
                  type="button"
                  onClick={() => setCurrentPage((prev) => Math.min(totalPages, prev + 1))}
                  disabled={currentPage === totalPages}
                  style={{
                    ...pageButtonStyle,
                    opacity: currentPage === totalPages ? 0.45 : 1,
                    cursor: currentPage === totalPages ? "not-allowed" : "pointer",
                  }}
                >
                  →
                </button>
              </div>
            </div>

            {usersLoading ? (
              <div style={emptyStateStyle}>Loading users...</div>
            ) : usersError ? (
              <div style={errorStateStyle}>{usersError}</div>
            ) : paginatedUsers.length > 0 ? (
              <div style={{ display: "grid", gap: 12 }}>
                {paginatedUsers.map((user) => (
                  <UserRow
                    key={user.id}
                    initials={getInitials(user)}
                    name={getDisplayName(user)}
                    email={user.email}
                    role={user.role || "user"}
                    status={normalizeStatus(user.status)}
                    createdAt={formatCreatedAt(user.created_at)}
                    onClick={() => setSelectedUserId(user.id)}
                  />
                ))}
              </div>
            ) : (
              <div style={emptyStateStyle}>No users match your current filters.</div>
            )}
          </section>
        </>
      )}
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

function UserRow({ initials, name, email, role, status, createdAt, onClick }) {
  const isActive = status === "Active";

  return (
    <>
      <button
        type="button"
        onClick={onClick}
        className="portal-user-row"
        style={{
          display: "grid",
          gridTemplateColumns: "auto 1fr auto auto",
          gap: 14,
          alignItems: "center",
          width: "100%",
          padding: "14px 16px",
          borderRadius: 18,
          background: "rgba(255,255,255,0.04)",
          border: "1px solid rgba(255,255,255,0.06)",
          textAlign: "left",
          cursor: "pointer",
          color: "inherit",
          position: "relative",
          overflow: "hidden",
          transition:
            "transform 0.24s ease, border-color 0.24s ease, box-shadow 0.24s ease, background 0.24s ease",
        }}
      >
        <span
          className="portal-user-row-shine"
          style={{
            position: "absolute",
            top: 0,
            left: "-35%",
            width: "32%",
            height: "100%",
            background:
              "linear-gradient(90deg, rgba(255,255,255,0) 0%, rgba(103,232,249,0.18) 50%, rgba(255,255,255,0) 100%)",
            transform: "skewX(-20deg)",
            pointerEvents: "none",
          }}
        />

        <div
          className="portal-user-row-avatar"
          style={{
            width: 44,
            height: 44,
            borderRadius: "50%",
            display: "grid",
            placeItems: "center",
            fontWeight: 900,
            color: "#081120",
            background: "linear-gradient(135deg, #67e8f9 0%, #a78bfa 100%)",
            boxShadow: "0 8px 18px rgba(103,232,249,0.14)",
            transition: "transform 0.24s ease, box-shadow 0.24s ease",
          }}
        >
          {initials}
        </div>

        <div
          className="portal-user-row-main"
          style={{
            minWidth: 0,
            transition: "transform 0.24s ease",
          }}
        >
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

        <div
          className="portal-user-row-meta"
          style={{
            textAlign: "right",
            transition: "transform 0.24s ease",
          }}
        >
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
            transition: "transform 0.24s ease",
          }}
        >
          {status}
        </span>
      </button>

      <style>
        {`
          .portal-user-row:hover {
            transform: translateY(-4px) scale(1.008);
            background: rgba(255,255,255,0.07);
            border-color: rgba(103,232,249,0.32);
            box-shadow:
              0 20px 40px rgba(0,0,0,0.34),
              0 0 0 1px rgba(103,232,249,0.08),
              0 0 28px rgba(103,232,249,0.10);
          }

          .portal-user-row:hover .portal-user-row-shine {
            animation: portalUserRowShine 0.85s ease;
          }

          .portal-user-row:hover .portal-user-row-avatar {
            transform: scale(1.08) rotate(-4deg);
            box-shadow:
              0 12px 24px rgba(103,232,249,0.20),
              0 0 18px rgba(167,139,250,0.18);
          }

          .portal-user-row:hover .portal-user-row-main,
          .portal-user-row:hover .portal-user-row-meta {
            transform: translateX(3px);
          }

          @keyframes portalUserRowShine {
            0% {
              left: -35%;
            }
            100% {
              left: 120%;
            }
          }
        `}
      </style>
    </>
  );
}

function EmbeddedUserDetail({ userId, onBack }) {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    const loadUser = async () => {
      try {
        setLoading(true);
        setError("");

        const token = localStorage.getItem("portalToken");

        const response = await fetch(`/v1/admin/users/${userId}`, {
          method: "GET",
          headers: {
            "Content-Type": "application/json",
            ...(token ? { Authorization: `Bearer ${token}` } : {}),
          },
        });

        let data = null;
        try {
          data = await response.json();
        } catch (_err) {
          data = null;
        }

        if (!response.ok) {
          throw new Error(data?.message || data?.error || "Failed to load user.");
        }

        const normalizedUser = data?.user || data;
        setUser(normalizedUser || null);
      } catch (err) {
        setError(err.message || "Failed to load user.");
        setUser(null);
      } finally {
        setLoading(false);
      }
    };

    loadUser();
  }, [userId]);

  if (loading) {
    return (
      <section style={{ ...cardStyle, display: "grid", gap: 18 }}>
        <button type="button" onClick={onBack} style={backButtonStyle}>
          ← Back to Users
        </button>
        <div style={emptyStateStyle}>Loading user...</div>
      </section>
    );
  }

  if (error || !user) {
    return (
      <section style={{ ...cardStyle, display: "grid", gap: 18 }}>
        <button type="button" onClick={onBack} style={backButtonStyle}>
          ← Back to Users
        </button>
        <div style={errorStateStyle}>{error || "User not found."}</div>
      </section>
    );
  }

  const displayName = getDisplayName(user);
  const initials = getInitials(user);
  const normalizedStatus = normalizeStatus(user.status);
  const isActive = normalizedStatus === "Active";

  return (
    <div style={{ display: "grid", gap: 22 }}>
      <button type="button" onClick={onBack} style={backButtonStyle}>
        ← Back to Users
      </button>

      <section
        style={{
          ...cardStyle,
          padding: 0,
          background:
            "radial-gradient(circle at top right, rgba(168,85,247,0.18), transparent 28%), radial-gradient(circle at top left, rgba(34,211,238,0.16), transparent 26%), rgba(15, 23, 42, 0.82)",
        }}
      >
        <Glow color="rgba(103,232,249,0.14)" />

        <div
          style={{
            padding: "30px 30px 26px",
            display: "grid",
            gap: 24,
          }}
        >
          <div
            style={{
              display: "flex",
              justifyContent: "space-between",
              gap: 20,
              alignItems: "flex-start",
              flexWrap: "wrap",
            }}
          >
            <div
              style={{
                display: "flex",
                gap: 20,
                alignItems: "center",
                flexWrap: "wrap",
              }}
            >
              <div
                style={{
                  width: 88,
                  height: 88,
                  borderRadius: "50%",
                  display: "grid",
                  placeItems: "center",
                  fontWeight: 900,
                  fontSize: "1.55rem",
                  color: "#081120",
                  background: "linear-gradient(135deg, #67e8f9 0%, #a78bfa 100%)",
                  boxShadow:
                    "0 18px 36px rgba(103,232,249,0.18), 0 0 24px rgba(167,139,250,0.14)",
                }}
              >
                {initials}
              </div>

              <div>
                <div style={labelStyle}>User Profile</div>

                <h1
                  style={{
                    margin: "10px 0 8px",
                    color: "#ffffff",
                    fontSize: "clamp(2rem, 4vw, 3.1rem)",
                    lineHeight: 1,
                    letterSpacing: "-0.04em",
                    fontWeight: 900,
                  }}
                >
                  {displayName}
                </h1>

                <p
                  style={{
                    margin: 0,
                    color: "#a5b4fc",
                    fontSize: "1.02rem",
                    fontWeight: 600,
                  }}
                >
                  {user.email}
                </p>
              </div>
            </div>

            <div
              style={{
                display: "flex",
                gap: 10,
                flexWrap: "wrap",
                alignItems: "center",
              }}
            >
              <span
                style={{
                  padding: "8px 14px",
                  borderRadius: 999,
                  background: "rgba(255,255,255,0.06)",
                  border: "1px solid rgba(255,255,255,0.08)",
                  color: "#dbeafe",
                  fontSize: "0.85rem",
                  fontWeight: 800,
                }}
              >
                {user.role || "User"}
              </span>

              <span
                style={{
                  padding: "8px 14px",
                  borderRadius: 999,
                  background: isActive ? "rgba(34,197,94,0.14)" : "rgba(239,68,68,0.14)",
                  border: isActive
                    ? "1px solid rgba(34,197,94,0.26)"
                    : "1px solid rgba(239,68,68,0.26)",
                  color: isActive ? "#86efac" : "#fca5a5",
                  fontSize: "0.85rem",
                  fontWeight: 800,
                }}
              >
                {normalizedStatus}
              </span>
            </div>
          </div>

          <div
            style={{
              display: "grid",
              gridTemplateColumns: "repeat(auto-fit, minmax(180px, 1fr))",
              gap: 14,
            }}
          >
            <InfoCard label="User ID" value={String(user.id)} />
            <InfoCard label="Phone" value={user.phone || "—"} />
            <InfoCard label="Preferred Name" value={user.preferred_name || "—"} />
            <InfoCard label="Timezone" value={user.timezone || "—"} />
          </div>
        </div>
      </section>

      <div
        style={{
          display: "grid",
          gridTemplateColumns: "repeat(auto-fit, minmax(320px, 1fr))",
          gap: 20,
        }}
      >
        <section style={cardStyle}>
          <SectionMiniHeader
            title="Personal Information"
            subtitle="Core profile and account identity"
          />
          <div style={infoGridStyle}>
            <InfoRow label="First Name" value={user.first_name} />
            <InfoRow label="Last Name" value={user.last_name} />
            <InfoRow label="Preferred Name" value={user.preferred_name} />
            <InfoRow label="Email" value={user.email} />
            <InfoRow label="Phone" value={user.phone} />
            <InfoRow label="Date of Birth" value={formatDate(user.date_of_birth)} />
            <InfoRow label="Preferred Language" value={user.preferred_language} />
            <InfoRow label="Timezone" value={user.timezone} />
          </div>
        </section>

        <section style={cardStyle}>
          <SectionMiniHeader
            title="Account Status"
            subtitle="Permissions, marketing, and verification"
          />
          <div style={infoGridStyle}>
            <InfoRow label="Role" value={user.role} />
            <InfoRow label="Status" value={normalizedStatus} />
            <InfoRow
              label="Marketing Opt In"
              value={user.marketing_opt_in ? "Yes" : "No"}
            />
            <InfoRow
              label="Phone Verified At"
              value={formatDateTime(user.phone_verified_at)}
            />
            <InfoRow
              label="Last Login At"
              value={formatDateTime(user.last_login_at)}
            />
            <InfoRow
              label="Last Seen At"
              value={formatDateTime(user.last_seen_at)}
            />
          </div>
        </section>
      </div>

      <section style={cardStyle}>
        <SectionMiniHeader
          title="Record Timestamps"
          subtitle="Database and account lifecycle information"
        />

        <div
          style={{
            display: "grid",
            gridTemplateColumns: "repeat(auto-fit, minmax(240px, 1fr))",
            gap: 14,
          }}
        >
          <InfoCard label="Created At" value={formatDateTime(user.created_at)} />
          <InfoCard label="Updated At" value={formatDateTime(user.updated_at)} />
          <InfoCard label="User ID" value={String(user.id)} />
        </div>
      </section>
    </div>
  );
}

function SectionMiniHeader({ title, subtitle }) {
  return (
    <div style={{ marginBottom: 18 }}>
      <h2
        style={{
          margin: 0,
          color: "#ffffff",
          fontSize: "1.2rem",
          fontWeight: 900,
          letterSpacing: "-0.02em",
        }}
      >
        {title}
      </h2>
      <p
        style={{
          margin: "6px 0 0",
          color: "#94a3b8",
          fontSize: "0.95rem",
        }}
      >
        {subtitle}
      </p>
    </div>
  );
}

function InfoRow({ label, value }) {
  return (
    <div
      style={{
        padding: "14px 0",
        borderBottom: "1px solid rgba(255,255,255,0.06)",
        display: "grid",
        gap: 6,
      }}
    >
      <div
        style={{
          color: "#94a3b8",
          fontSize: "0.84rem",
          fontWeight: 700,
        }}
      >
        {label}
      </div>
      <div
        style={{
          color: "#ffffff",
          fontSize: "1rem",
          fontWeight: 800,
          lineHeight: 1.4,
          wordBreak: "break-word",
        }}
      >
        {value || "—"}
      </div>
    </div>
  );
}

function InfoCard({ label, value }) {
  return (
    <div
      style={{
        borderRadius: 18,
        padding: 18,
        background: "rgba(255,255,255,0.04)",
        border: "1px solid rgba(255,255,255,0.08)",
      }}
    >
      <div
        style={{
          color: "#94a3b8",
          fontSize: "0.84rem",
          fontWeight: 700,
          marginBottom: 8,
        }}
      >
        {label}
      </div>

      <div
        style={{
          color: "#ffffff",
          fontSize: "1rem",
          fontWeight: 800,
          lineHeight: 1.4,
          wordBreak: "break-word",
        }}
      >
        {value || "—"}
      </div>
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

function getDisplayName(user) {
  const fullName = `${user.first_name || ""} ${user.last_name || ""}`.trim();
  return fullName || user.preferred_name || user.email || "Unnamed User";
}

function getInitials(user) {
  const first = user.first_name?.[0] || user.preferred_name?.[0] || user.email?.[0] || "U";
  const last = user.last_name?.[0] || "";
  return `${first}${last}`.toUpperCase();
}

function normalizeStatus(status) {
  return String(status || "").toLowerCase() === "active" ? "Active" : "Inactive";
}

function formatCreatedAt(createdAt) {
  if (!createdAt) return "—";

  try {
    return new Date(createdAt).toLocaleDateString("en-US", {
      month: "short",
      year: "numeric",
    });
  } catch (_err) {
    return "—";
  }
}

function formatDate(value) {
  if (!value) return "—";

  try {
    return new Date(value).toLocaleDateString("en-US", {
      year: "numeric",
      month: "short",
      day: "numeric",
    });
  } catch (_err) {
    return "—";
  }
}

function formatDateTime(value) {
  if (!value) return "—";

  try {
    return new Date(value).toLocaleString("en-US", {
      year: "numeric",
      month: "short",
      day: "numeric",
      hour: "numeric",
      minute: "2-digit",
    });
  } catch (_err) {
    return "—";
  }
}