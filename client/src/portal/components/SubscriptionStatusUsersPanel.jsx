import React, { useEffect, useMemo, useState } from "react";

const STATUS_CONFIG = {
  cancelled: {
    status: "cancelled",
    emoji: "🛑",
    title: "Cancelled Users",
    eyebrow: "Subscription Status",
    subtitle:
      "Users who cancelled their subscription. Some may still have access until their current billing period ends.",
    heroTitle: "Cancelled Subscriptions",
    heroText:
      "Cancelled users are churn signals. They may still be inside their paid access window, but their subscription is no longer set to renew.",
    accent: "#fb7185",
    softAccent: "rgba(251,113,133,0.14)",
    emptyTitle: "No cancelled users found",
    emptyBody:
      "There are currently no subscriptions marked as cancelled.",
  },
  expired: {
    status: "expired",
    emoji: "⌛",
    title: "Expired Users",
    eyebrow: "Subscription Status",
    subtitle:
      "Users whose paid subscription access has ended.",
    heroTitle: "Expired Subscriptions",
    heroText:
      "Expired users are lost-access accounts. These users no longer have an active paid subscription window.",
    accent: "#fca5a5",
    softAccent: "rgba(252,165,165,0.14)",
    emptyTitle: "No expired users found",
    emptyBody:
      "There are currently no subscriptions marked as expired.",
  },
};

export default function SubscriptionStatusUsersPanel({ status = "cancelled" }) {
  const config = STATUS_CONFIG[status] || STATUS_CONFIG.cancelled;

  const [subscribers, setSubscribers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  const [searchTerm, setSearchTerm] = useState("");
  const [platformFilter, setPlatformFilter] = useState("all");
  const [productFilter, setProductFilter] = useState("all");

  useEffect(() => {
    const loadSubscribers = async () => {
      try {
        setLoading(true);
        setError("");

        const token = localStorage.getItem("portalToken");

        const response = await fetch("/v1/admin/billing/subscribers", {
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
          console.error("[SubscriptionStatusUsersPanel] JSON parse failed:", jsonError);
        }

        if (!response.ok) {
          throw new Error(
            data?.message || data?.error || "Failed to load subscribers."
          );
        }

        const normalizedSubscribers = Array.isArray(data?.subscribers)
          ? data.subscribers
          : [];

        setSubscribers(normalizedSubscribers);
      } catch (err) {
        console.error("[SubscriptionStatusUsersPanel] Load failed:", err);

        setSubscribers([]);
        setError(err.message || "Failed to load subscribers.");
      } finally {
        setLoading(false);
      }
    };

    loadSubscribers();
  }, []);

  const statusSubscribers = useMemo(() => {
    return subscribers.filter((subscriber) => {
      return String(subscriber?.status || "").toLowerCase() === config.status;
    });
  }, [subscribers, config.status]);

  const filterOptions = useMemo(() => {
    return {
      platforms: uniqueCleanValues(statusSubscribers.map((item) => item.store)),
      products: uniqueCleanValues(statusSubscribers.map((item) => item.product_id)),
    };
  }, [statusSubscribers]);

  const filteredSubscribers = useMemo(() => {
    const normalizedSearch = searchTerm.trim().toLowerCase();

    return statusSubscribers.filter((subscriber) => {
      const store = subscriber.store || "";
      const product = subscriber.product_id || "";
      const user = subscriber.user || {};

      const matchesPlatform =
        platformFilter === "all" || store === platformFilter;

      const matchesProduct =
        productFilter === "all" || product === productFilter;

      const searchableText = [
        subscriber.id,
        subscriber.user_id,
        subscriber.status,
        subscriber.product_id,
        subscriber.entitlement_key,
        subscriber.store,
        subscriber.environment,
        subscriber.transaction_id,
        subscriber.original_transaction_id,
        user.name,
        user.email,
        user.phone,
      ]
        .filter(Boolean)
        .join(" ")
        .toLowerCase();

      const matchesSearch =
        normalizedSearch.length === 0 ||
        searchableText.includes(normalizedSearch);

      return matchesPlatform && matchesProduct && matchesSearch;
    });
  }, [statusSubscribers, searchTerm, platformFilter, productFilter]);

  const stats = useMemo(() => {
    const total = statusSubscribers.length;

    const appStore = statusSubscribers.filter((subscriber) =>
      ["APP_STORE", "APPLE", "IOS"].includes(
        String(subscriber.store || "").toUpperCase()
      )
    ).length;

    const playStore = statusSubscribers.filter((subscriber) =>
      ["PLAY_STORE", "GOOGLE_PLAY", "ANDROID"].includes(
        String(subscriber.store || "").toUpperCase()
      )
    ).length;

    const withPeriodEnd = statusSubscribers.filter(
      (subscriber) => subscriber.current_period_end
    ).length;

    const monthlyRevenueAtRiskCents = statusSubscribers.reduce(
      (sum, subscriber) => sum + Number(subscriber?.price?.cents || 0),
      0
    );

    return {
      total,
      appStore,
      playStore,
      withPeriodEnd,
      monthlyRevenueAtRiskCents,
    };
  }, [statusSubscribers]);

  return (
    <div style={{ display: "grid", gap: 22 }}>
      <section
        style={{
          borderRadius: 28,
          padding: "26px 28px",
          background: `radial-gradient(circle at top left, ${config.softAccent}, transparent 30%), radial-gradient(circle at top right, rgba(147,197,253,0.12), transparent 30%), rgba(15,23,42,0.82)`,
          border: `1px solid ${hexToRgba(config.accent, 0.22)}`,
          boxShadow: "0 22px 54px rgba(0,0,0,0.26)",
          overflow: "hidden",
          position: "relative",
        }}
      >
        <div
          style={{
            position: "absolute",
            right: -52,
            top: -64,
            width: 220,
            height: 220,
            borderRadius: "50%",
            background: hexToRgba(config.accent, 0.08),
            pointerEvents: "none",
          }}
        />

        <div style={{ position: "relative", zIndex: 2 }}>
          <div
            style={{
              display: "inline-flex",
              alignItems: "center",
              gap: 8,
              padding: "7px 12px",
              borderRadius: 999,
              background: hexToRgba(config.accent, 0.12),
              border: `1px solid ${hexToRgba(config.accent, 0.22)}`,
              color: config.accent,
              fontSize: "0.78rem",
              fontWeight: 950,
              textTransform: "uppercase",
              letterSpacing: "0.08em",
              marginBottom: 14,
            }}
          >
            {config.emoji} {config.eyebrow}
          </div>

          <h2
            style={{
              margin: 0,
              color: "#ffffff",
              fontSize: "clamp(2rem, 5vw, 4rem)",
              fontWeight: 950,
              letterSpacing: "-0.08em",
              lineHeight: 0.98,
            }}
          >
            {config.heroTitle}
          </h2>

          <p
            style={{
              margin: "14px 0 0",
              color: "#cbd5e1",
              fontSize: "1rem",
              lineHeight: 1.65,
              maxWidth: 860,
              fontWeight: 750,
            }}
          >
            {config.heroText}
          </p>
        </div>
      </section>

      <section
        style={{
          display: "grid",
          gridTemplateColumns: "repeat(auto-fit, minmax(210px, 1fr))",
          gap: 14,
        }}
      >
        <StatCard
          label={config.title}
          value={loading ? "..." : formatNumber(stats.total)}
          subtext={`Subscriptions currently marked ${config.status}.`}
          color={config.accent}
        />

        <StatCard
          label="App Store"
          value={loading ? "..." : formatNumber(stats.appStore)}
          subtext="Users tied to Apple App Store."
          color="#67e8f9"
        />

        <StatCard
          label="Google Play"
          value={loading ? "..." : formatNumber(stats.playStore)}
          subtext="Users tied to Google Play."
          color="#86efac"
        />

        <StatCard
          label="Recorded Value"
          value={loading ? "..." : formatMoneyFromCents(stats.monthlyRevenueAtRiskCents)}
          subtext="Sum of stored subscription price values in this status."
          color="#fcd34d"
        />
      </section>

      <section style={panelStyle}>
        <PanelHeader
          eyebrow="Filters"
          title={`Search ${config.title}`}
          subtitle="Filter by name, email, phone, product, platform, transaction ID, or subscription metadata."
        />

        <div
          className="subscription-status-filter-grid"
          style={{
            display: "grid",
            gridTemplateColumns:
              "minmax(260px, 1fr) minmax(170px, 220px) minmax(180px, 240px)",
            gap: 12,
            marginTop: 18,
          }}
        >
          <input
            type="text"
            placeholder="Search name, email, phone, product, transaction..."
            value={searchTerm}
            onChange={(event) => setSearchTerm(event.target.value)}
            style={inputStyle}
          />

          <select
            value={platformFilter}
            onChange={(event) => setPlatformFilter(event.target.value)}
            style={selectStyle}
          >
            <option value="all">All Platforms</option>
            {filterOptions.platforms.map((platform) => (
              <option key={platform} value={platform}>
                {platform}
              </option>
            ))}
          </select>

          <select
            value={productFilter}
            onChange={(event) => setProductFilter(event.target.value)}
            style={selectStyle}
          >
            <option value="all">All Products</option>
            {filterOptions.products.map((product) => (
              <option key={product} value={product}>
                {product}
              </option>
            ))}
          </select>
        </div>
      </section>

      <section style={panelStyle}>
        <div
          style={{
            display: "flex",
            justifyContent: "space-between",
            gap: 14,
            alignItems: "flex-start",
            flexWrap: "wrap",
            marginBottom: 18,
          }}
        >
          <PanelHeader
            eyebrow="Users"
            title={config.title}
            subtitle={
              loading
                ? `Loading ${config.status} subscriptions...`
                : `Showing ${formatNumber(filteredSubscribers.length)} of ${formatNumber(
                    statusSubscribers.length
                  )} ${config.status} subscriptions.`
            }
          />

          <div
            style={{
              textAlign: "right",
              color: "#94a3b8",
              fontSize: "0.8rem",
              fontWeight: 800,
              lineHeight: 1.5,
            }}
          >
            <div>Status</div>
            <div style={{ color: config.accent, fontWeight: 950 }}>
              {config.status.toUpperCase()}
            </div>
          </div>
        </div>

        {loading ? (
          <EmptyState
            title={`Loading ${config.title.toLowerCase()}...`}
            body="Fetching subscription records from the backend."
            color={config.accent}
          />
        ) : error ? (
          <EmptyState title="Could not load users" body={error} color="#fca5a5" />
        ) : filteredSubscribers.length === 0 ? (
          <EmptyState
            title={config.emptyTitle}
            body={config.emptyBody}
            color={config.accent}
          />
        ) : (
          <div style={{ display: "grid", gap: 12 }}>
            {filteredSubscribers.map((subscriber) => (
              <SubscriptionStatusRow
                key={subscriber.id}
                subscriber={subscriber}
                config={config}
              />
            ))}
          </div>
        )}
      </section>

      <style>
        {`
          .subscription-status-row:hover {
            transform: translateY(-2px);
            box-shadow: 0 18px 38px rgba(0,0,0,0.28) !important;
            border-color: rgba(147,197,253,0.22) !important;
          }

          .subscription-status-filter-grid select option {
            background: #0f172a;
            color: #e2e8f0;
          }

          @media (max-width: 920px) {
            .subscription-status-filter-grid {
              grid-template-columns: 1fr !important;
            }

            .subscription-status-row-grid {
              grid-template-columns: 1fr !important;
            }
          }
        `}
      </style>
    </div>
  );
}

function SubscriptionStatusRow({ subscriber, config }) {
  const user = subscriber.user || {};
  const initials = getInitials(user.name || user.email || "User");

  return (
    <article
      className="subscription-status-row"
      style={{
        borderRadius: 22,
        padding: 18,
        background:
          "radial-gradient(circle at top right, rgba(59,130,246,0.08), transparent 34%), rgba(255,255,255,0.035)",
        border: `1px solid ${hexToRgba(config.accent, 0.22)}`,
        boxShadow: "0 14px 32px rgba(0,0,0,0.18)",
        transition:
          "transform 0.18s ease, border-color 0.18s ease, box-shadow 0.18s ease",
      }}
    >
      <div
        className="subscription-status-row-grid"
        style={{
          display: "grid",
          gridTemplateColumns:
            "minmax(260px, 1.3fr) minmax(180px, 0.7fr) minmax(170px, 0.7fr) minmax(190px, 0.8fr)",
          gap: 14,
          alignItems: "center",
        }}
      >
        <div style={{ display: "flex", alignItems: "center", gap: 13, minWidth: 0 }}>
          <div
            style={{
              width: 48,
              height: 48,
              borderRadius: "50%",
              display: "grid",
              placeItems: "center",
              flexShrink: 0,
              color: "#0f172a",
              fontWeight: 950,
              background: `linear-gradient(135deg, ${config.accent}, #93c5fd)`,
              boxShadow: `0 14px 26px ${hexToRgba(config.accent, 0.16)}`,
            }}
          >
            {initials}
          </div>

          <div style={{ minWidth: 0 }}>
            <div
              style={{
                color: "#ffffff",
                fontSize: "1rem",
                fontWeight: 950,
                whiteSpace: "nowrap",
                overflow: "hidden",
                textOverflow: "ellipsis",
              }}
              title={user.name || "Unknown User"}
            >
              {user.name || "Unknown User"}
            </div>

            <div
              style={{
                color: "#cbd5e1",
                fontSize: "0.84rem",
                fontWeight: 750,
                marginTop: 4,
                whiteSpace: "nowrap",
                overflow: "hidden",
                textOverflow: "ellipsis",
              }}
              title={user.email || "No email"}
            >
              {user.email || "No email"}
            </div>

            <div
              style={{
                color: "#94a3b8",
                fontSize: "0.78rem",
                fontWeight: 750,
                marginTop: 3,
              }}
            >
              {formatPhone(user.phone) || "No phone"}
            </div>
          </div>
        </div>

        <MiniBlock
          label="Product"
          value={subscriber.product_id || "Unknown"}
          color="#93c5fd"
        />

        <MiniBlock
          label="Platform"
          value={subscriber.store || "Unknown"}
          color="#86efac"
        />

        <MiniBlock
          label={config.status === "cancelled" ? "Cancelled At" : "Expired At"}
          value={
            config.status === "cancelled"
              ? formatDateTime(subscriber.cancelled_at) ||
                formatDateTime(subscriber.updated_at)
              : formatDateTime(subscriber.expired_at) ||
                formatDateTime(subscriber.current_period_end)
          }
          color={config.accent}
        />
      </div>

      <div
        style={{
          display: "grid",
          gridTemplateColumns: "repeat(auto-fit, minmax(190px, 1fr))",
          gap: 10,
          marginTop: 16,
        }}
      >
        <DetailBox label="Price" value={subscriber.price?.formatted || "—"} />
        <DetailBox
          label="Current Period Start"
          value={formatDateTime(subscriber.current_period_start) || "—"}
        />
        <DetailBox
          label="Current Period End"
          value={formatDateTime(subscriber.current_period_end) || "—"}
        />
        <DetailBox
          label="Cancel At Period End"
          value={subscriber.cancel_at_period_end ? "Yes" : "No"}
        />
        <DetailBox label="Environment" value={subscriber.environment || "—"} />
        <DetailBox label="Transaction ID" value={subscriber.transaction_id || "—"} />
      </div>
    </article>
  );
}

function MiniBlock({ label, value, color }) {
  return (
    <div
      style={{
        borderRadius: 16,
        padding: 13,
        background: "rgba(255,255,255,0.035)",
        border: `1px solid ${hexToRgba(color, 0.16)}`,
        minWidth: 0,
      }}
    >
      <div
        style={{
          color: "#94a3b8",
          fontSize: "0.7rem",
          fontWeight: 950,
          textTransform: "uppercase",
          letterSpacing: "0.08em",
          marginBottom: 6,
        }}
      >
        {label}
      </div>

      <div
        style={{
          color,
          fontSize: "0.9rem",
          fontWeight: 950,
          whiteSpace: "nowrap",
          overflow: "hidden",
          textOverflow: "ellipsis",
        }}
        title={String(value || "—")}
      >
        {value || "—"}
      </div>
    </div>
  );
}

function DetailBox({ label, value }) {
  return (
    <div
      style={{
        borderRadius: 15,
        padding: "11px 12px",
        background: "rgba(15,23,42,0.55)",
        border: "1px solid rgba(255,255,255,0.07)",
        minWidth: 0,
      }}
    >
      <div
        style={{
          color: "#64748b",
          fontSize: "0.68rem",
          fontWeight: 950,
          textTransform: "uppercase",
          letterSpacing: "0.08em",
          marginBottom: 5,
        }}
      >
        {label}
      </div>

      <div
        style={{
          color: "#cbd5e1",
          fontSize: "0.82rem",
          fontWeight: 800,
          whiteSpace: "nowrap",
          overflow: "hidden",
          textOverflow: "ellipsis",
        }}
        title={String(value || "—")}
      >
        {value || "—"}
      </div>
    </div>
  );
}

function StatCard({ label, value, subtext, color }) {
  return (
    <div
      style={{
        borderRadius: 24,
        padding: 20,
        background:
          "radial-gradient(circle at top right, rgba(59,130,246,0.10), transparent 32%), rgba(15,23,42,0.78)",
        border: `1px solid ${hexToRgba(color, 0.22)}`,
        boxShadow: "0 18px 44px rgba(0,0,0,0.20)",
      }}
    >
      <div
        style={{
          color,
          fontSize: "0.74rem",
          fontWeight: 950,
          textTransform: "uppercase",
          letterSpacing: "0.08em",
        }}
      >
        {label}
      </div>

      <div
        style={{
          marginTop: 10,
          color: "#ffffff",
          fontSize: "2.1rem",
          fontWeight: 950,
          letterSpacing: "-0.07em",
          lineHeight: 1,
        }}
      >
        {value}
      </div>

      <div
        style={{
          marginTop: 10,
          color: "#94a3b8",
          fontSize: "0.88rem",
          fontWeight: 750,
          lineHeight: 1.45,
        }}
      >
        {subtext}
      </div>
    </div>
  );
}

function EmptyState({ title, body, color }) {
  return (
    <div
      style={{
        borderRadius: 22,
        padding: 24,
        background: "rgba(255,255,255,0.035)",
        border: `1px solid ${hexToRgba(color, 0.22)}`,
      }}
    >
      <div
        style={{
          color,
          fontSize: "1rem",
          fontWeight: 950,
          marginBottom: 8,
        }}
      >
        {title}
      </div>

      <div
        style={{
          color: "#94a3b8",
          fontSize: "0.92rem",
          lineHeight: 1.55,
          fontWeight: 750,
        }}
      >
        {body}
      </div>
    </div>
  );
}

function PanelHeader({ eyebrow, title, subtitle }) {
  return (
    <div>
      <div
        style={{
          color: "#93c5fd",
          fontSize: "0.74rem",
          fontWeight: 950,
          textTransform: "uppercase",
          letterSpacing: "0.08em",
        }}
      >
        {eyebrow}
      </div>

      <h3
        style={{
          margin: "7px 0 0",
          color: "#ffffff",
          fontSize: "1.25rem",
          fontWeight: 950,
          letterSpacing: "-0.03em",
        }}
      >
        {title}
      </h3>

      <p
        style={{
          margin: "7px 0 0",
          color: "#94a3b8",
          fontSize: "0.9rem",
          lineHeight: 1.55,
        }}
      >
        {subtitle}
      </p>
    </div>
  );
}

function uniqueCleanValues(values) {
  return Array.from(
    new Set(
      values
        .map((value) => (value === null || value === undefined ? "" : String(value)))
        .map((value) => value.trim())
        .filter(Boolean)
    )
  ).sort();
}

function getInitials(value) {
  const parts = String(value || "")
    .trim()
    .split(/\s+/)
    .filter(Boolean);

  if (parts.length === 0) return "U";
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();

  return `${parts[0][0] || ""}${parts[1][0] || ""}`.toUpperCase();
}

function formatNumber(value) {
  const numberValue = Number(value || 0);

  return new Intl.NumberFormat("en-US").format(numberValue);
}

function formatMoneyFromCents(value) {
  const cents = Number(value || 0);

  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
  }).format(cents / 100);
}

function formatPhone(value) {
  const digits = String(value || "").replace(/\D/g, "");

  if (digits.length === 10) {
    return `(${digits.slice(0, 3)}) ${digits.slice(3, 6)}-${digits.slice(6)}`;
  }

  if (digits.length === 11 && digits[0] === "1") {
    return `+1 (${digits.slice(1, 4)}) ${digits.slice(4, 7)}-${digits.slice(7)}`;
  }

  return value || "";
}

function formatDateTime(value) {
  if (!value) return "";

  const date = new Date(value);

  if (Number.isNaN(date.getTime())) return "";

  return date.toLocaleString("en-US", {
    month: "short",
    day: "numeric",
    year: "numeric",
    hour: "numeric",
    minute: "2-digit",
  });
}

function hexToRgba(hex, alpha) {
  const safeHex = String(hex || "#ffffff").replace("#", "");

  if (safeHex.length !== 6) {
    return `rgba(255,255,255,${alpha})`;
  }

  const r = parseInt(safeHex.slice(0, 2), 16);
  const g = parseInt(safeHex.slice(2, 4), 16);
  const b = parseInt(safeHex.slice(4, 6), 16);

  return `rgba(${r},${g},${b},${alpha})`;
}

const panelStyle = {
  borderRadius: 26,
  padding: 22,
  background:
    "radial-gradient(circle at top right, rgba(59,130,246,0.10), transparent 32%), rgba(15,23,42,0.78)",
  border: "1px solid rgba(255,255,255,0.09)",
  boxShadow: "0 18px 44px rgba(0,0,0,0.24)",
  overflow: "hidden",
};

const inputStyle = {
  width: "100%",
  minHeight: 48,
  borderRadius: 16,
  border: "1px solid rgba(148,163,184,0.24)",
  background: "rgba(15,23,42,0.78)",
  color: "#e2e8f0",
  padding: "0 15px",
  outline: "none",
  fontSize: "0.92rem",
  fontWeight: 750,
};

const selectStyle = {
  width: "100%",
  minHeight: 48,
  borderRadius: 16,
  border: "1px solid rgba(148,163,184,0.24)",
  background: "rgba(15,23,42,0.78)",
  color: "#e2e8f0",
  padding: "0 14px",
  outline: "none",
  fontSize: "0.9rem",
  fontWeight: 850,
};