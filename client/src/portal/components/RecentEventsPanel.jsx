import React, { useEffect, useMemo, useState } from "react";

const EVENT_COLORS = {
  INITIAL_PURCHASE: "#86efac",
  RENEWAL: "#67e8f9",
  CANCELLATION: "#fb7185",
  EXPIRATION: "#fca5a5",
  BILLING_ISSUE: "#fde68a",
  UNCANCELLATION: "#c4b5fd",
  PRODUCT_CHANGE: "#93c5fd",
  NON_RENEWING_PURCHASE: "#86efac",
};

const EVENT_EMOJIS = {
  INITIAL_PURCHASE: "🟢",
  RENEWAL: "🔁",
  CANCELLATION: "🛑",
  EXPIRATION: "⌛",
  BILLING_ISSUE: "⚠️",
  UNCANCELLATION: "✅",
  PRODUCT_CHANGE: "🔄",
  NON_RENEWING_PURCHASE: "💳",
};

export default function RecentEventsPanel() {
  const [events, setEvents] = useState([]);
  const [meta, setMeta] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  const [searchTerm, setSearchTerm] = useState("");
  const [eventTypeFilter, setEventTypeFilter] = useState("all");
  const [storeFilter, setStoreFilter] = useState("all");
  const [environmentFilter, setEnvironmentFilter] = useState("all");

  useEffect(() => {
    const loadRecentEvents = async () => {
      try {
        setLoading(true);
        setError("");

        const token = localStorage.getItem("portalToken");

        const response = await fetch("/v1/admin/billing/recent_events", {
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
          console.error("[RecentEventsPanel] JSON parse failed:", jsonError);
        }

        if (!response.ok) {
          throw new Error(
            data?.message || data?.error || "Failed to load recent events."
          );
        }

        const normalizedEvents = Array.isArray(data?.events) ? data.events : [];

        setEvents(normalizedEvents);
        setMeta(data?.meta || null);
      } catch (err) {
        console.error("[RecentEventsPanel] Load failed:", err);

        setEvents([]);
        setMeta(null);
        setError(err.message || "Failed to load recent events.");
      } finally {
        setLoading(false);
      }
    };

    loadRecentEvents();
  }, []);

  const filterOptions = useMemo(() => {
    const eventTypes = uniqueCleanValues(events.map((event) => event.event_type));
    const stores = uniqueCleanValues(events.map((event) => event.store));
    const environments = uniqueCleanValues(
      events.map((event) => event.environment)
    );

    return {
      eventTypes,
      stores,
      environments,
    };
  }, [events]);

  const filteredEvents = useMemo(() => {
    const normalizedSearch = searchTerm.trim().toLowerCase();

    return events.filter((event) => {
      const eventType = event.event_type || "";
      const store = event.store || "";
      const environment = event.environment || "";

      const matchesEventType =
        eventTypeFilter === "all" || eventType === eventTypeFilter;

      const matchesStore = storeFilter === "all" || store === storeFilter;

      const matchesEnvironment =
        environmentFilter === "all" || environment === environmentFilter;

      const searchableText = [
        event.id,
        event.user_id,
        event.event_id,
        event.event_type,
        event.app_user_id,
        event.product_id,
        event.entitlement_key,
        event.transaction_id,
        event.original_transaction_id,
        event.store,
        event.environment,
        event.currency,
      ]
        .filter(Boolean)
        .join(" ")
        .toLowerCase();

      const matchesSearch =
        normalizedSearch.length === 0 ||
        searchableText.includes(normalizedSearch);

      return (
        matchesEventType &&
        matchesStore &&
        matchesEnvironment &&
        matchesSearch
      );
    });
  }, [events, searchTerm, eventTypeFilter, storeFilter, environmentFilter]);

  const eventStats = useMemo(() => {
    const totalEvents = events.length;
    const filteredCount = filteredEvents.length;

    const purchaseEvents = events.filter((event) =>
      ["INITIAL_PURCHASE", "NON_RENEWING_PURCHASE"].includes(event.event_type)
    ).length;

    const renewalEvents = events.filter(
      (event) => event.event_type === "RENEWAL"
    ).length;

    const riskEvents = events.filter((event) =>
      ["CANCELLATION", "EXPIRATION", "BILLING_ISSUE"].includes(event.event_type)
    ).length;

    const latestEvent = events[0] || null;

    return {
      totalEvents,
      filteredCount,
      purchaseEvents,
      renewalEvents,
      riskEvents,
      latestEvent,
    };
  }, [events, filteredEvents]);

  return (
    <div style={{ display: "grid", gap: 22 }}>
      <section
        style={{
          borderRadius: 28,
          padding: "26px 28px",
          background:
            "radial-gradient(circle at top left, rgba(34,211,238,0.16), transparent 30%), radial-gradient(circle at top right, rgba(168,85,247,0.14), transparent 30%), rgba(15,23,42,0.82)",
          border: "1px solid rgba(147,197,253,0.16)",
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
            background: "rgba(147,197,253,0.08)",
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
              background: "rgba(59,130,246,0.12)",
              border: "1px solid rgba(147,197,253,0.20)",
              color: "#bfdbfe",
              fontSize: "0.78rem",
              fontWeight: 950,
              textTransform: "uppercase",
              letterSpacing: "0.08em",
              marginBottom: 14,
            }}
          >
            ⚡ RevenueCat Timeline
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
            Recent Events
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
            RevenueCat lifecycle activity including purchases, renewals,
            cancellations, expirations, billing issues, product changes, and
            webhook-backed subscription events.
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
          label="Total Events"
          value={loading ? "..." : formatNumber(eventStats.totalEvents)}
          subtext="Recent lifecycle events loaded"
          color="#93c5fd"
        />

        <StatCard
          label="Purchases"
          value={loading ? "..." : formatNumber(eventStats.purchaseEvents)}
          subtext="Initial or non-renewing purchases"
          color="#86efac"
        />

        <StatCard
          label="Renewals"
          value={loading ? "..." : formatNumber(eventStats.renewalEvents)}
          subtext="Recurring successful renewals"
          color="#67e8f9"
        />

        <StatCard
          label="Risk Events"
          value={loading ? "..." : formatNumber(eventStats.riskEvents)}
          subtext="Cancellation, expiration, or billing issue"
          color="#fca5a5"
        />
      </section>

      <section style={panelStyle}>
        <PanelHeader
          eyebrow="Filters"
          title="Search Event Timeline"
          subtitle="Narrow by event type, store, environment, transaction ID, product ID, or RevenueCat app user ID."
        />

        <div
          style={{
            display: "grid",
            gridTemplateColumns:
              "minmax(260px, 1fr) minmax(180px, 220px) minmax(160px, 210px) minmax(160px, 210px)",
            gap: 12,
            marginTop: 18,
          }}
          className="recent-events-filter-grid"
        >
          <input
            type="text"
            placeholder="Search event, product, transaction, app user..."
            value={searchTerm}
            onChange={(event) => setSearchTerm(event.target.value)}
            style={inputStyle}
          />

          <select
            value={eventTypeFilter}
            onChange={(event) => setEventTypeFilter(event.target.value)}
            style={selectStyle}
          >
            <option value="all">All Event Types</option>
            {filterOptions.eventTypes.map((eventType) => (
              <option key={eventType} value={eventType}>
                {eventType}
              </option>
            ))}
          </select>

          <select
            value={storeFilter}
            onChange={(event) => setStoreFilter(event.target.value)}
            style={selectStyle}
          >
            <option value="all">All Stores</option>
            {filterOptions.stores.map((store) => (
              <option key={store} value={store}>
                {store}
              </option>
            ))}
          </select>

          <select
            value={environmentFilter}
            onChange={(event) => setEnvironmentFilter(event.target.value)}
            style={selectStyle}
          >
            <option value="all">All Environments</option>
            {filterOptions.environments.map((environment) => (
              <option key={environment} value={environment}>
                {environment}
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
            eyebrow="Event Timeline"
            title="Recent RevenueCat Events"
            subtitle={
              loading
                ? "Loading recent subscription lifecycle events..."
                : `Showing ${formatNumber(
                    filteredEvents.length
                  )} of ${formatNumber(events.length)} events.`
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
            <div>Generated</div>
            <div style={{ color: "#dbeafe", fontWeight: 950 }}>
              {formatDateTime(meta?.generated_at) || "—"}
            </div>
          </div>
        </div>

        {loading ? (
          <EmptyState
            title="Loading recent events..."
            body="Fetching RevenueCat lifecycle activity from the backend."
            color="#93c5fd"
          />
        ) : error ? (
          <EmptyState title="Could not load recent events" body={error} color="#fca5a5" />
        ) : filteredEvents.length === 0 ? (
          <EmptyState
            title="No events match these filters"
            body="Try clearing the search box or changing the event type, store, or environment filter."
            color="#fde68a"
          />
        ) : (
          <div style={{ display: "grid", gap: 12 }}>
            {filteredEvents.map((event) => (
              <EventRow key={event.id || event.event_id} event={event} />
            ))}
          </div>
        )}
      </section>

      <style>
        {`
          .recent-event-row:hover {
            transform: translateY(-2px);
            box-shadow: 0 18px 38px rgba(0,0,0,0.28) !important;
            border-color: rgba(147,197,253,0.22) !important;
          }

          .recent-events-filter-grid select option {
            background: #0f172a;
            color: #e2e8f0;
          }

          @media (max-width: 980px) {
            .recent-events-filter-grid {
              grid-template-columns: 1fr !important;
            }
          }
        `}
      </style>
    </div>
  );
}

function EventRow({ event }) {
  const eventType = event.event_type || "UNKNOWN";
  const color = EVENT_COLORS[eventType] || "#93c5fd";
  const emoji = EVENT_EMOJIS[eventType] || "⚡";

  return (
    <article
      className="recent-event-row"
      style={{
        borderRadius: 22,
        padding: 18,
        background:
          "radial-gradient(circle at top right, rgba(59,130,246,0.08), transparent 34%), rgba(255,255,255,0.035)",
        border: `1px solid ${hexToRgba(color, 0.22)}`,
        boxShadow: "0 14px 32px rgba(0,0,0,0.18)",
        transition:
          "transform 0.18s ease, border-color 0.18s ease, box-shadow 0.18s ease",
      }}
    >
      <div
        style={{
          display: "grid",
          gridTemplateColumns: "minmax(0, 1.2fr) repeat(3, minmax(130px, 0.4fr))",
          gap: 14,
          alignItems: "center",
        }}
        className="recent-event-row-grid"
      >
        <div style={{ minWidth: 0 }}>
          <div
            style={{
              display: "flex",
              alignItems: "center",
              gap: 10,
              minWidth: 0,
            }}
          >
            <span
              style={{
                width: 38,
                height: 38,
                borderRadius: 14,
                display: "grid",
                placeItems: "center",
                background: hexToRgba(color, 0.12),
                border: `1px solid ${hexToRgba(color, 0.24)}`,
                flexShrink: 0,
              }}
            >
              {emoji}
            </span>

            <div style={{ minWidth: 0 }}>
              <div
                style={{
                  color,
                  fontSize: "0.78rem",
                  fontWeight: 950,
                  textTransform: "uppercase",
                  letterSpacing: "0.08em",
                }}
              >
                {eventType}
              </div>

              <div
                style={{
                  color: "#ffffff",
                  fontSize: "1.02rem",
                  fontWeight: 950,
                  marginTop: 4,
                  whiteSpace: "nowrap",
                  overflow: "hidden",
                  textOverflow: "ellipsis",
                }}
              >
                {event.product_id || "Unknown Product"}
              </div>
            </div>
          </div>

          <div
            style={{
              display: "flex",
              gap: 8,
              flexWrap: "wrap",
              marginTop: 12,
            }}
          >
            <Pill label={event.store || "UNKNOWN STORE"} color="#93c5fd" />
            <Pill label={event.environment || "UNKNOWN ENV"} color="#c4b5fd" />
            <Pill
              label={event.currency || "USD"}
              color="#86efac"
            />
          </div>
        </div>

        <EventMiniBlock
          label="Price"
          value={event.price?.formatted || formatMoneyFromCents(event.price?.cents)}
          color={color}
        />

        <EventMiniBlock
          label="Purchased"
          value={formatDateTime(event.purchased_at) || "—"}
          color="#93c5fd"
        />

        <EventMiniBlock
          label="Created"
          value={formatDateTime(event.created_at) || "—"}
          color="#c4b5fd"
        />
      </div>

      <div
        style={{
          display: "grid",
          gridTemplateColumns: "repeat(auto-fit, minmax(220px, 1fr))",
          gap: 10,
          marginTop: 16,
        }}
      >
        <DetailBox label="App User ID" value={event.app_user_id} />
        <DetailBox label="Transaction ID" value={event.transaction_id} />
        <DetailBox
          label="Original Transaction ID"
          value={event.original_transaction_id}
        />
        <DetailBox label="Entitlement" value={event.entitlement_key} />
        <DetailBox label="Event ID" value={event.event_id} />
        <DetailBox label="User ID" value={event.user_id} />
      </div>

      <style>
        {`
          @media (max-width: 980px) {
            .recent-event-row-grid {
              grid-template-columns: 1fr !important;
            }
          }
        `}
      </style>
    </article>
  );
}

function EventMiniBlock({ label, value, color }) {
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
          color: "#ffffff",
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

function Pill({ label, color }) {
  return (
    <span
      style={{
        display: "inline-flex",
        alignItems: "center",
        padding: "5px 9px",
        borderRadius: 999,
        background: hexToRgba(color, 0.1),
        border: `1px solid ${hexToRgba(color, 0.18)}`,
        color,
        fontSize: "0.7rem",
        fontWeight: 950,
        textTransform: "uppercase",
        letterSpacing: "0.06em",
      }}
    >
      {label}
    </span>
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