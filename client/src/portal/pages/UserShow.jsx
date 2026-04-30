import React, { useEffect, useState } from "react";
import { Link, useParams } from "react-router-dom";
import UserControlCenter from "../components/users/controlCenter/UserControlCenter";

const pageCardStyle = {
  position: "relative",
  overflow: "hidden",
  borderRadius: 28,
  padding: 28,
  background: "rgba(15, 23, 42, 0.78)",
  border: "1px solid rgba(255,255,255,0.10)",
  boxShadow: "0 20px 60px rgba(0,0,0,0.28)",
  backdropFilter: "blur(14px)",
};

const sectionCardStyle = {
  position: "relative",
  overflow: "hidden",
  borderRadius: 24,
  padding: 24,
  background: "rgba(15, 23, 42, 0.72)",
  border: "1px solid rgba(255,255,255,0.08)",
  boxShadow: "0 18px 44px rgba(0,0,0,0.22)",
  backdropFilter: "blur(14px)",
};

export default function UserShow() {
  const { id } = useParams();
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    const loadUser = async () => {
      try {
        setLoading(true);
        setError("");

        const token = localStorage.getItem("portalToken");

        const response = await fetch(`/v1/admin/users/${id}`, {
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
          throw new Error(
            data?.message ||
              data?.error ||
              "Failed to load user."
          );
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
  }, [id]);

  if (loading) {
    return (
      <div style={{ display: "grid", gap: 20 }}>
        <Link to="/dashboard" style={backLinkStyle}>
          ← Back to Dashboard
        </Link>

        <div style={pageCardStyle}>
          <h1 style={{ margin: 0, color: "#ffffff" }}>Loading user...</h1>
        </div>
      </div>
    );
  }

  if (error || !user) {
    return (
      <div style={{ display: "grid", gap: 20 }}>
        <Link to="/dashboard" style={backLinkStyle}>
          ← Back to Dashboard
        </Link>

        <div style={pageCardStyle}>
          <h1 style={{ margin: 0, color: "#ffffff" }}>
            {error || "User not found"}
          </h1>
        </div>
      </div>
    );
  }

  const displayName = getDisplayName(user);
  const initials = getInitials(user);
  const normalizedStatus = normalizeStatus(user.status);
  const isActive = normalizedStatus === "Active";

  return (
    <div style={{ display: "grid", gap: 22 }}>
      <Link to="/dashboard" style={backLinkStyle}>
        ← Back to Dashboard
      </Link>

      <section
        style={{
          ...pageCardStyle,
          padding: 0,
          background:
            "radial-gradient(circle at top right, rgba(168,85,247,0.18), transparent 28%), radial-gradient(circle at top left, rgba(34,211,238,0.16), transparent 26%), rgba(15, 23, 42, 0.82)",
        }}
      >
        <Glow color="rgba(103,232,249,0.14)" top={-40} right={-40} size={160} />
        <Glow color="rgba(167,139,250,0.14)" top={"auto"} right={80} bottom={-70} size={180} />

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
                <div style={eyebrowStyle}>User Profile</div>

                <h1
                  style={{
                    margin: "6px 0 8px",
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
              <span style={rolePillStyle}>{user.role || "User"}</span>
              <span
                style={{
                  ...statusPillStyle,
                  background: isActive ? "rgba(34,197,94,0.14)" : "rgba(239,68,68,0.14)",
                  border: isActive
                    ? "1px solid rgba(34,197,94,0.26)"
                    : "1px solid rgba(239,68,68,0.26)",
                  color: isActive ? "#86efac" : "#fca5a5",
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
            <HeroStat label="User ID" value={String(user.id)} />
            <HeroStat label="Phone" value={user.phone || "—"} />
            <HeroStat label="Preferred Name" value={user.preferred_name || "—"} />
            <HeroStat label="Timezone" value={user.timezone || "—"} />
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
        <section style={sectionCardStyle}>
          <Glow color="rgba(103,232,249,0.10)" top={-30} right={-30} size={120} />
          <SectionHeader
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

        <section style={sectionCardStyle}>
          <Glow color="rgba(167,139,250,0.10)" top={-30} right={-30} size={120} />
          <SectionHeader
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

      <section style={sectionCardStyle}>
        <Glow color="rgba(244,114,182,0.10)" top={-30} right={-30} size={120} />
        <SectionHeader
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

      <UserControlCenter userId={id} />
    </div>
  );
}

function SectionHeader({ title, subtitle }) {
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

function HeroStat({ label, value }) {
  return (
    <div
      style={{
        borderRadius: 18,
        padding: "16px 16px 14px",
        background: "rgba(255,255,255,0.04)",
        border: "1px solid rgba(255,255,255,0.08)",
      }}
    >
      <div
        style={{
          color: "#94a3b8",
          fontSize: "0.82rem",
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
          lineHeight: 1.35,
          wordBreak: "break-word",
        }}
      >
        {value || "—"}
      </div>
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

function Glow({ color, top, right, bottom, size }) {
  return (
    <div
      style={{
        position: "absolute",
        top,
        right,
        bottom,
        width: size,
        height: size,
        borderRadius: "50%",
        background: color,
        filter: "blur(34px)",
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

const eyebrowStyle = {
  display: "inline-flex",
  alignItems: "center",
  gap: 8,
  padding: "8px 14px",
  borderRadius: 999,
  background: "rgba(255,255,255,0.06)",
  border: "1px solid rgba(255,255,255,0.08)",
  color: "#93c5fd",
  fontSize: "0.8rem",
  fontWeight: 800,
};

const rolePillStyle = {
  padding: "8px 14px",
  borderRadius: 999,
  background: "rgba(255,255,255,0.06)",
  border: "1px solid rgba(255,255,255,0.08)",
  color: "#dbeafe",
  fontSize: "0.85rem",
  fontWeight: 800,
};

const statusPillStyle = {
  padding: "8px 14px",
  borderRadius: 999,
  fontSize: "0.85rem",
  fontWeight: 800,
};

const infoGridStyle = {
  display: "grid",
  gap: 2,
};

const backLinkStyle = {
  color: "#93c5fd",
  textDecoration: "none",
  fontWeight: 800,
  width: "fit-content",
  fontSize: "0.96rem",
};