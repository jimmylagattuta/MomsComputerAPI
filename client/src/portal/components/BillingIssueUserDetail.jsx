import React, { useEffect, useMemo, useState } from "react";
import Glow from "./Glow";
import {
  cardStyle,
  errorStateStyle,
  sectionSubtextStyle,
  sectionTitleStyle,
} from "../styles/portalStyles";
import {
  formatDateTime,
  formatMoneyFromCents,
} from "../utils/portalFormatters";

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

const backButtonStyle = {
  width: "fit-content",
  padding: "11px 14px",
  borderRadius: 14,
  background: "rgba(255,255,255,0.06)",
  border: "1px solid rgba(147,197,253,0.18)",
  color: "#93c5fd",
  fontWeight: 900,
  cursor: "pointer",
};

const warningPillStyle = {
  padding: "8px 14px",
  borderRadius: 999,
  background: "rgba(250,204,21,0.14)",
  border: "1px solid rgba(250,204,21,0.32)",
  color: "#fde68a",
  fontSize: "0.85rem",
  fontWeight: 900,
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

export default function BillingIssueUserDetail({ billingIssue, onBack }) {
  const billingUserId = billingIssue?.user_id || billingIssue?.user?.id;

  const [user, setUser] = useState(billingIssue?.user || null);
  const [loading, setLoading] = useState(Boolean(billingUserId));
  const [error, setError] = useState("");
  const [copiedField, setCopiedField] = useState("");

  useEffect(() => {
    if (!billingUserId) {
      setLoading(false);
      setError("");
      setUser(billingIssue?.user || null);
      return;
    }

    const loadUser = async () => {
      try {
        setLoading(true);
        setError("");

        const token = localStorage.getItem("portalToken");

        const response = await fetch(`/v1/admin/users/${billingUserId}`, {
          method: "GET",
          headers: {
            "Content-Type": "application/json",
            ...(token ? { Authorization: `Bearer ${token}` } : {}),
          },
        });

        let data = null;

        try {
          data = await response.json();
        } catch (_jsonError) {
          data = null;
        }

        if (!response.ok) {
          throw new Error(data?.message || data?.error || "Failed to load user.");
        }

        setUser(data?.user || data || billingIssue?.user || null);
      } catch (err) {
        console.error("[BillingIssueUserDetail] Load user error:", err);
        setError(err.message || "Failed to load user.");
        setUser(billingIssue?.user || null);
      } finally {
        setLoading(false);
      }
    };

    loadUser();
  }, [billingUserId, billingIssue]);

  const displayName = useMemo(() => {
    return getDisplayName(user, billingIssue);
  }, [user, billingIssue]);

  const initials = useMemo(() => {
    return getInitials(displayName, getEmail(user, billingIssue));
  }, [displayName, user, billingIssue]);

  const email = getEmail(user, billingIssue);
  const phone = formatPhoneNumber(getPhone(user, billingIssue));
  const product = getProduct(billingIssue);

  const platform = titleize(
    billingIssue?.store ||
      billingIssue?.platform ||
      billingIssue?.app_store ||
      billingIssue?.provider ||
      "—"
  );

  const amountCents =
    billingIssue?.price_cents ??
    billingIssue?.amount_cents ??
    billingIssue?.revenue_cents ??
    billingIssue?.price?.cents ??
    billingIssue?.price?.amount_cents ??
    billingIssue?.plan?.price_cents ??
    getFallbackPriceCents(product);

  const billingIssueAt =
    billingIssue?.billing_issue_at ||
    billingIssue?.updated_at ||
    billingIssue?.last_validated_at;

  const periodEnd =
    billingIssue?.current_period_end ||
    billingIssue?.expiration_at ||
    billingIssue?.expires_at ||
    billingIssue?.renewal_at;

  const moneyText =
    billingIssue?.price?.formatted || formatMoneyFromCents(amountCents);

  const copyToClipboard = async (value, fieldName) => {
    if (!value || value === "—") return;

    try {
      await navigator.clipboard.writeText(value);
      setCopiedField(fieldName);

      window.setTimeout(() => {
        setCopiedField("");
      }, 1400);
    } catch (err) {
      console.error("[BillingIssueUserDetail] Clipboard copy failed:", err);
    }
  };

  return (
    <div style={{ display: "grid", gap: 22 }}>
      <button type="button" onClick={onBack} style={backButtonStyle}>
        ← Back to Billing Issues
      </button>

      {loading ? (
        <section style={cardStyle}>
          <h2 style={sectionTitleStyle}>Loading billing issue user...</h2>
          <p style={sectionSubtextStyle}>Pulling the full account record.</p>
        </section>
      ) : null}

      {!loading && error ? <div style={errorStateStyle}>{error}</div> : null}

      {!loading ? (
        <>
          <section
            style={{
              ...pageCardStyle,
              padding: 0,
              background:
                "radial-gradient(circle at top right, rgba(250,204,21,0.18), transparent 28%), radial-gradient(circle at top left, rgba(251,113,133,0.15), transparent 26%), rgba(15, 23, 42, 0.82)",
            }}
          >
            <Glow color="rgba(250,204,21,0.16)" />
            <Glow color="rgba(251,113,133,0.12)" />

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
                        "linear-gradient(135deg, #fde68a 0%, #fb7185 100%)",
                      boxShadow:
                        "0 18px 36px rgba(250,204,21,0.18), 0 0 24px rgba(251,113,133,0.14)",
                    }}
                  >
                    {initials}
                  </div>

                  <div>
                    <div style={eyebrowStyle}>Billing Issue Profile</div>

                    <h1
                      style={{
                        margin: "6px 0 10px",
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
                  <span style={warningPillStyle}>Billing Issue</span>
                  <span style={rolePillStyle}>{user?.role || "User"}</span>
                </div>
              </div>

              <div
                style={{
                  display: "grid",
                  gridTemplateColumns: "repeat(auto-fit, minmax(180px, 1fr))",
                  gap: 14,
                }}
              >
                <HeroStat
                  label="User ID"
                  value={String(billingUserId || "—")}
                  valueColor="#ffffff"
                />
                <HeroStat
                  label="Product"
                  value={product}
                  valueColor="#c4b5fd"
                />
                <HeroStat
                  label="Platform"
                  value={platform}
                  valueColor="#93c5fd"
                />
                <HeroStat
                  label="Amount"
                  value={moneyText}
                  valueColor="#86efac"
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
              <SectionHeader
                title="Billing Issue Details"
                subtitle="Current payment-risk status for this subscription"
              />

              <div style={infoGridStyle}>
                <InfoRow
                  label="Status"
                  value="Billing Issue"
                  valueColor="#fde68a"
                />
                <InfoRow
                  label="Billing Issue Since"
                  value={formatDateTime(billingIssueAt)}
                  valueColor="#fca5a5"
                />
                <InfoRow
                  label="Current Period End"
                  value={formatDateTime(periodEnd)}
                  valueColor="#93c5fd"
                />
                <InfoRow
                  label="Cancel At Period End"
                  value={booleanText(billingIssue?.cancel_at_period_end)}
                  valueColor="#ffffff"
                />
                <InfoRow
                  label="Billing Period"
                  value={billingIssue?.billing_period}
                  valueColor="#c4b5fd"
                />
                <InfoRow
                  label="Currency"
                  value={billingIssue?.currency || "USD"}
                  valueColor="#86efac"
                />
              </div>
            </section>

            <section style={sectionCardStyle}>
              <SectionHeader
                title="Subscription Identity"
                subtitle="RevenueCat/store identifiers for tracking"
              />

              <div style={infoGridStyle}>
                <InfoRow
                  label="Subscription ID"
                  value={billingIssue?.id}
                  valueColor="#ffffff"
                />
                <InfoRow
                  label="Provider"
                  value={billingIssue?.provider}
                  valueColor="#c4b5fd"
                />
                <InfoRow
                  label="Provider Subscription ID"
                  value={billingIssue?.provider_subscription_id}
                  valueColor="#93c5fd"
                />
                <InfoRow
                  label="RevenueCat App User ID"
                  value={billingIssue?.revenuecat_app_user_id}
                  valueColor="#93c5fd"
                />
                <InfoRow
                  label="Transaction ID"
                  value={billingIssue?.transaction_id}
                  valueColor="#93c5fd"
                />
                <InfoRow
                  label="Original Transaction ID"
                  value={billingIssue?.original_transaction_id}
                  valueColor="#93c5fd"
                />
              </div>
            </section>
          </div>

          <section style={sectionCardStyle}>
            <SectionHeader
              title="User Account Snapshot"
              subtitle="Basic account information attached to the billing issue"
            />

            <div
              style={{
                display: "grid",
                gridTemplateColumns: "repeat(auto-fit, minmax(220px, 1fr))",
                gap: 14,
              }}
            >
              <InfoCard
                label="First Name"
                value={user?.first_name}
                valueColor="#ffffff"
              />
              <InfoCard
                label="Last Name"
                value={user?.last_name}
                valueColor="#ffffff"
              />
              <InfoCard
                label="Preferred Name"
                value={user?.preferred_name}
                valueColor="#c4b5fd"
              />
              <InfoCard
                label="Phone"
                value={phone}
                valueColor="#93c5fd"
              />
              <InfoCard
                label="User Status"
                value={user?.status}
                valueColor="#86efac"
              />
              <InfoCard
                label="Created At"
                value={formatDateTime(user?.created_at)}
                valueColor="#fcd34d"
              />
            </div>
          </section>
        </>
      ) : null}
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

function HeroStat({ label, value, valueColor = "#ffffff" }) {
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
          color: valueColor,
          fontSize: "1rem",
          fontWeight: 900,
          lineHeight: 1.35,
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
            className="contact-copy-icon"
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
        className="contact-copy-badge"
        style={sharedStyle}
      >
        {content}

        <style>
          {`
            .contact-copy-badge:hover {
              background: rgba(250,204,21,0.16) !important;
              border-color: rgba(250,204,21,0.44) !important;
              box-shadow: 0 0 22px rgba(250,204,21,0.10) !important;
            }

            .contact-copy-badge:hover .contact-copy-icon {
              opacity: 1 !important;
              transform: translateX(0) !important;
            }

            .contact-copy-badge:focus-visible {
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

function getDisplayName(user, billingIssue) {
  const firstName =
    user?.first_name ||
    billingIssue?.first_name ||
    billingIssue?.user?.first_name ||
    "";

  const lastName =
    user?.last_name ||
    billingIssue?.last_name ||
    billingIssue?.user?.last_name ||
    "";

  const fullName = `${firstName} ${lastName}`.trim();

  return (
    user?.name ||
    billingIssue?.name ||
    billingIssue?.full_name ||
    billingIssue?.user?.name ||
    fullName ||
    user?.preferred_name ||
    user?.email ||
    billingIssue?.email ||
    billingIssue?.user_email ||
    billingIssue?.customer_email ||
    "Unnamed Billing Issue User"
  );
}

function getEmail(user, billingIssue) {
  return (
    user?.email ||
    billingIssue?.email ||
    billingIssue?.user_email ||
    billingIssue?.customer_email ||
    billingIssue?.user?.email ||
    "—"
  );
}

function getPhone(user, billingIssue) {
  return (
    user?.phone ||
    billingIssue?.phone ||
    billingIssue?.user?.phone ||
    "—"
  );
}

function formatPhoneNumber(value) {
  if (!value || value === "—") return "—";

  const rawValue = String(value).trim();
  const digits = rawValue.replace(/\D/g, "");

  if (digits.length === 10) {
    return `(${digits.slice(0, 3)}) ${digits.slice(3, 6)}-${digits.slice(6)}`;
  }

  if (digits.length === 11 && digits[0] === "1") {
    return `+1 (${digits.slice(1, 4)}) ${digits.slice(4, 7)}-${digits.slice(7)}`;
  }

  return rawValue;
}

function getInitials(name, email) {
  const safeName = String(name || "").trim();

  if (safeName && safeName !== "Unnamed Billing Issue User") {
    const pieces = safeName.split(" ").filter(Boolean);
    const first = pieces[0]?.[0] || "B";
    const last = pieces.length > 1 ? pieces[pieces.length - 1]?.[0] || "" : "";

    return `${first}${last}`.toUpperCase();
  }

  return String(email || "BI").slice(0, 2).toUpperCase();
}

function getProduct(billingIssue) {
  return (
    billingIssue?.product_id ||
    billingIssue?.provider_product_id ||
    billingIssue?.plan_name ||
    billingIssue?.plan?.name ||
    "—"
  );
}

function getFallbackPriceCents(product) {
  const normalizedProduct = String(product || "").toLowerCase();

  if (normalizedProduct.includes("moms_computer_monthly")) return 999;
  if (normalizedProduct.includes("moms_computer_yearly")) return 9999;

  return 0;
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

function booleanText(value) {
  if (value === true) return "Yes";
  if (value === false) return "No";
  return "—";
}

const eyebrowStyle = {
  display: "inline-flex",
  alignItems: "center",
  gap: 8,
  padding: "8px 14px",
  borderRadius: 999,
  background: "rgba(255,255,255,0.06)",
  border: "1px solid rgba(255,255,255,0.08)",
  color: "#fde68a",
  fontSize: "0.8rem",
  fontWeight: 900,
};

const infoGridStyle = {
  display: "grid",
  gap: 2,
};