import React, { useEffect, useState } from "react";
import {
  cardStyle,
  emptyStateStyle,
  errorStateStyle,
  backButtonStyle,
  labelStyle,
  infoGridStyle,
} from "../styles/portalStyles";
import {
  formatDate,
  formatDateTime,
  getDisplayName,
  getInitials,
  normalizeStatus,
} from "../utils/portalFormatters";
import Glow from "./Glow";
import { InfoCard, InfoRow, SectionMiniHeader } from "./InfoBlocks";

export default function EmbeddedUserDetail({ userId, onBack }) {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    const loadUser = async () => {
      try {
        console.log("[Portal Dashboard] Starting embedded user load:", userId);

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
          console.error("[Portal Dashboard] Embedded user JSON parse failed:", jsonError);
        }

        console.log("[Portal Dashboard] Embedded user response status:", response.status);
        console.log("[Portal Dashboard] Embedded user raw response data:", data);

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