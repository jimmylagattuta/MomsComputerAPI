import React, { useEffect, useMemo, useState } from "react";
import {
  cardStyle,
  emptyStateStyle,
  errorStateStyle,
  backButtonStyle,
  labelStyle,
} from "../styles/portalStyles";
import {
  formatDate,
  formatDateTime,
  getDisplayName,
  getInitials,
  normalizeStatus,
} from "../utils/portalFormatters";
import Glow from "./Glow";
import UserControlCenter from "./users/controlCenter/UserControlCenter";

const sectionCardStyle = {
  ...cardStyle,
  position: "relative",
  overflow: "hidden",
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

const statusPillBaseStyle = {
  padding: "8px 14px",
  borderRadius: 999,
  fontSize: "0.85rem",
  fontWeight: 900,
};

export default function EmbeddedUserDetail({ userId, onBack }) {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [copiedField, setCopiedField] = useState("");

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
        } catch (jsonError) {
          console.error(
            "[Portal Dashboard] Embedded user JSON parse failed:",
            jsonError
          );
        }

        if (!response.ok) {
          throw new Error(data?.message || data?.error || "Failed to load user.");
        }

        const normalizedUser = data?.user || data;

        setUser(normalizedUser || null);
      } catch (err) {
        console.error("[Portal Dashboard] Embedded user load error:", err);

        setError(err.message || "Failed to load user.");
        setUser(null);
      } finally {
        setLoading(false);
      }
    };

    loadUser();
  }, [userId]);

  const displayName = useMemo(() => {
    if (!user) return "User";
    return getDisplayName(user);
  }, [user]);

  const initials = useMemo(() => {
    if (!user) return "U";
    return getInitials(user);
  }, [user]);

  const copyToClipboard = async (value, fieldName) => {
    if (!value || value === "—") return;

    try {
      await navigator.clipboard.writeText(value);
      setCopiedField(fieldName);

      window.setTimeout(() => {
        setCopiedField("");
      }, 1400);
    } catch (err) {
      console.error("[EmbeddedUserDetail] Clipboard copy failed:", err);
    }
  };

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

  const normalizedStatus = normalizeStatus(user.status);
  const isActive = normalizedStatus === "Active";
  const email = user.email || "—";
  const phone = formatPhoneNumber(user.phone);

  return (
    <div style={{ display: "grid", gap: 22 }}>
      <button type="button" onClick={onBack} style={backButtonStyle}>
        ← Back to Users
      </button>

      <section
        style={{
          ...cardStyle,
          padding: 0,
          overflow: "hidden",
          background:
            "radial-gradient(circle at top right, rgba(168,85,247,0.18), transparent 28%), radial-gradient(circle at top left, rgba(34,211,238,0.16), transparent 26%), rgba(15, 23, 42, 0.82)",
        }}
      >
        <Glow color="rgba(103,232,249,0.14)" />
        <Glow color="rgba(167,139,250,0.14)" />

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
                  background:
                    "linear-gradient(135deg, #67e8f9 0%, #a78bfa 100%)",
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
                    margin: "10px 0 10px",
                    color: "#ffffff",
                    fontSize: "clamp(2rem, 4vw, 3.1rem)",
                    lineHeight: 1,
                    letterSpacing: "-0.04em",
                    fontWeight: 900,
                  }}
                >
                  {displayName}
                </h1>

                <div
                  style={{
                    display: "flex",
                    gap: 12,
                    flexWrap: "wrap",
                    alignItems: "center",
                  }}
                >
                  <ContactBadge
                    label={copiedField === "email" ? "Copied" : "Email"}
                    value={email}
                    color="#fde68a"
                    background="rgba(250,204,21,0.10)"
                    border="1px solid rgba(250,204,21,0.24)"
                    clickable
                    title="Click to copy email"
                    onClick={() => copyToClipboard(email, "email")}
                  />

                  <ContactBadge
                    label="Phone"
                    value={phone}
                    color="#93c5fd"
                    background="rgba(59,130,246,0.10)"
                    border="1px solid rgba(147,197,253,0.24)"
                  />
                </div>
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
              <span style={rolePillStyle}>{titleize(user.role || "User")}</span>

              <span
                style={{
                  ...statusPillBaseStyle,
                  background: isActive
                    ? "rgba(34,197,94,0.14)"
                    : "rgba(239,68,68,0.14)",
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
            <InfoCard
              label="User ID"
              value={String(user.id)}
              valueColor="#ffffff"
            />
            <InfoCard label="Phone" value={phone} valueColor="#93c5fd" />
            <InfoCard
              label="Preferred Name"
              value={user.preferred_name || "—"}
              valueColor="#c4b5fd"
            />
            <InfoCard
              label="Timezone"
              value={user.timezone || "—"}
              valueColor="#fcd34d"
            />
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
          <Glow color="rgba(103,232,249,0.10)" />

          <SectionMiniHeader
            title="Personal Information"
            subtitle="Core profile and account identity"
          />

          <div style={infoGridStyle}>
            <InfoRow
              label="First Name"
              value={user.first_name}
              valueColor="#ffffff"
            />
            <InfoRow
              label="Last Name"
              value={user.last_name}
              valueColor="#ffffff"
            />
            <InfoRow
              label="Preferred Name"
              value={user.preferred_name}
              valueColor="#c4b5fd"
            />
            <InfoRow label="Email" value={email} valueColor="#fde68a" />
            <InfoRow label="Phone" value={phone} valueColor="#93c5fd" />
            <InfoRow
              label="Date of Birth"
              value={formatDate(user.date_of_birth)}
              valueColor="#fcd34d"
            />
            <InfoRow
              label="Preferred Language"
              value={user.preferred_language}
              valueColor="#86efac"
            />
            <InfoRow
              label="Timezone"
              value={user.timezone}
              valueColor="#fcd34d"
            />
          </div>
        </section>

        <section style={sectionCardStyle}>
          <Glow color="rgba(167,139,250,0.10)" />

          <SectionMiniHeader
            title="Account Status"
            subtitle="Permissions, marketing, and verification"
          />

          <div style={infoGridStyle}>
            <InfoRow
              label="Role"
              value={titleize(user.role)}
              valueColor="#c4b5fd"
            />
            <InfoRow
              label="Status"
              value={normalizedStatus}
              valueColor={isActive ? "#86efac" : "#fca5a5"}
            />
            <InfoRow
              label="Marketing Opt In"
              value={user.marketing_opt_in ? "Yes" : "No"}
              valueColor={user.marketing_opt_in ? "#86efac" : "#fca5a5"}
            />
            <InfoRow
              label="Phone Verified At"
              value={formatDateTime(user.phone_verified_at)}
              valueColor={user.phone_verified_at ? "#86efac" : "#fca5a5"}
            />
            <InfoRow
              label="Last Login At"
              value={formatDateTime(user.last_login_at)}
              valueColor="#93c5fd"
            />
            <InfoRow
              label="Last Seen At"
              value={formatDateTime(user.last_seen_at)}
              valueColor="#93c5fd"
            />
          </div>
        </section>
      </div>

      <section style={sectionCardStyle}>
        <Glow color="rgba(244,114,182,0.10)" />

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
          <InfoCard
            label="Created At"
            value={formatDateTime(user.created_at)}
            valueColor="#fcd34d"
          />
          <InfoCard
            label="Updated At"
            value={formatDateTime(user.updated_at)}
            valueColor="#93c5fd"
          />
          <InfoCard
            label="User ID"
            value={String(user.id)}
            valueColor="#ffffff"
          />
        </div>
      </section>

      <UserControlCenter userId={userId} user={user} />
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

function InfoCard({ label, value, valueColor = "#ffffff" }) {
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
          color: valueColor,
          fontSize: "1rem",
          fontWeight: 900,
          lineHeight: 1.4,
          wordBreak: "break-word",
        }}
      >
        {value || "—"}
      </div>
    </div>
  );
}

function InfoRow({ label, value, valueColor = "#ffffff" }) {
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
          color: valueColor,
          fontSize: "1rem",
          fontWeight: 900,
          lineHeight: 1.4,
          wordBreak: "break-word",
        }}
      >
        {value || "—"}
      </div>
    </div>
  );
}

function ContactBadge({
  label,
  value,
  color,
  background,
  border,
  clickable = false,
  title,
  onClick,
}) {
  const sharedStyle = {
    display: "inline-flex",
    alignItems: "center",
    gap: 8,
    padding: "9px 12px",
    borderRadius: 999,
    background,
    border,
    color,
    fontSize: "0.92rem",
    fontWeight: 800,
    maxWidth: "100%",
    cursor: clickable ? "pointer" : "default",
    transition:
      "border-color 0.2s ease, background 0.2s ease, box-shadow 0.2s ease",
  };

  const content = (
    <>
      <span
        style={{
          opacity: 0.78,
          fontSize: "0.78rem",
          fontWeight: 900,
          textTransform: "uppercase",
          letterSpacing: "0.04em",
        }}
      >
        {label}
      </span>

      <span
        style={{
          display: "inline-flex",
          alignItems: "center",
          gap: 7,
          minWidth: 0,
        }}
      >
        <span
          style={{
            color,
            whiteSpace: "nowrap",
            overflow: "hidden",
            textOverflow: "ellipsis",
          }}
        >
          {value || "—"}
        </span>

        {clickable ? (
          <span
            className="embedded-user-contact-copy-icon"
            aria-hidden="true"
            style={{
              opacity: 0,
              transform: "translateX(-3px)",
              transition: "opacity 0.18s ease, transform 0.18s ease",
              color,
              fontSize: "0.95rem",
              lineHeight: 1,
            }}
          >
            ⧉
          </span>
        ) : null}
      </span>
    </>
  );

  if (clickable) {
    return (
      <button
        type="button"
        title={title}
        onClick={onClick}
        className="embedded-user-contact-copy-badge"
        style={sharedStyle}
      >
        {content}

        <style>
          {`
            .embedded-user-contact-copy-badge:hover {
              background: rgba(250,204,21,0.16) !important;
              border-color: rgba(250,204,21,0.44) !important;
              box-shadow: 0 0 22px rgba(250,204,21,0.10) !important;
            }

            .embedded-user-contact-copy-badge:hover .embedded-user-contact-copy-icon {
              opacity: 1 !important;
              transform: translateX(0) !important;
            }

            .embedded-user-contact-copy-badge:focus-visible {
              outline: 2px solid rgba(250,204,21,0.72);
              outline-offset: 4px;
            }
          `}
        </style>
      </button>
    );
  }

  return <div style={sharedStyle}>{content}</div>;
}

function formatPhoneNumber(value) {
  if (!value || value === "—") return "—";

  const rawValue = String(value).trim();
  const digits = rawValue.replace(/\D/g, "");

  if (digits.length === 10) {
    return `(${digits.slice(0, 3)}) ${digits.slice(3, 6)}-${digits.slice(6)}`;
  }

  if (digits.length === 11 && digits[0] === "1") {
    return `+1 (${digits.slice(1, 4)}) ${digits.slice(4, 7)}-${digits.slice(
      7
    )}`;
  }

  return rawValue;
}

function titleize(value) {
  if (!value) return "—";

  return String(value)
    .replace(/_/g, " ")
    .replace(/-/g, " ")
    .replace(/\s+/g, " ")
    .trim()
    .replace(/\w\S*/g, (word) => {
      if (word.length <= 3 && word === word.toUpperCase()) return word;
      return word.charAt(0).toUpperCase() + word.slice(1).toLowerCase();
    });
}

const infoGridStyle = {
  display: "grid",
  gap: 2,
};