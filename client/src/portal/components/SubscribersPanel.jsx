import React, { useEffect, useMemo, useRef, useState } from "react";
import Glow from "./Glow";
import {
  cardStyle,
  emptyStateStyle,
  errorStateStyle,
  inputStyle,
  pageButtonStyle,
  pageIndicatorStyle,
  sectionSubtextStyle,
  sectionTitleStyle,
} from "../styles/portalStyles";
import {
  formatDateTime,
  formatMoneyFromCents,
} from "../utils/portalFormatters";

const SUBSCRIBERS_PER_PAGE = 25;

const optionStyle = {
  background: "#0f172a",
  color: "#ffffff",
};

const subscriberRowGridTemplateColumns =
  "58px minmax(260px, 1.4fr) minmax(220px, 1fr) 170px 240px 150px";

export default function SubscribersPanel({ onReady }) {
  const readyNotifiedRef = useRef(false);

  const [subscribers, setSubscribers] = useState([]);
  const [subscribersLoading, setSubscribersLoading] = useState(true);
  const [subscribersError, setSubscribersError] = useState("");

  const [search, setSearch] = useState("");
  const [statusFilter, setStatusFilter] = useState("All");
  const [platformFilter, setPlatformFilter] = useState("All");
  const [productFilter, setProductFilter] = useState("All");
  const [currentPage, setCurrentPage] = useState(1);

  useEffect(() => {
    const loadSubscribers = async () => {
      try {
        // console.log("[Portal Subscribers] Starting subscribers load...");

        setSubscribersLoading(true);
        setSubscribersError("");

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
          console.error("[Portal Subscribers] JSON parse failed:", jsonError);
        }

        // console.log("[Portal Subscribers] Response status:", response.status);
        // console.log("[Portal Subscribers] Raw response data:", data);

        if (!response.ok) {
          throw new Error(
            data?.message || data?.error || "Failed to load subscribers."
          );
        }

        const normalizedSubscribers = Array.isArray(data)
          ? data
          : Array.isArray(data?.subscribers)
          ? data.subscribers
          : Array.isArray(data?.subscriptions)
          ? data.subscriptions
          : [];

        // console.log(
        //   "[Portal Subscribers] Normalized subscriber count:",
        //   normalizedSubscribers.length
        // );

        setSubscribers(normalizedSubscribers);
      } catch (err) {
        console.error("[Portal Subscribers] Load error:", err);

        setSubscribers([]);
        setSubscribersError(err.message || "Failed to load subscribers.");
      } finally {
        setSubscribersLoading(false);
      }
    };

    loadSubscribers();
  }, []);

  useEffect(() => {
    if (subscribersLoading) return;
    if (readyNotifiedRef.current) return;

    readyNotifiedRef.current = true;

    window.requestAnimationFrame(() => {
      window.requestAnimationFrame(() => {
        if (typeof onReady === "function") {
          onReady();
        }
      });
    });
  }, [subscribersLoading, onReady]);

  const statusOptions = useMemo(() => {
    return buildUniqueOptions(subscribers, (subscriber) =>
      normalizeText(
        subscriber.status ||
          subscriber.subscription_status ||
          subscriber.current_status
      )
    );
  }, [subscribers]);

  const platformOptions = useMemo(() => {
    return buildUniqueOptions(subscribers, (subscriber) =>
      normalizeText(
        subscriber.store ||
          subscriber.platform ||
          subscriber.app_store ||
          subscriber.provider
      )
    );
  }, [subscribers]);

  const productOptions = useMemo(() => {
    return buildUniqueOptions(subscribers, (subscriber) =>
      normalizeText(
        subscriber.product_id ||
          subscriber.provider_product_id ||
          subscriber.plan_name ||
          subscriber.plan?.name
      )
    );
  }, [subscribers]);

  const filteredSubscribers = useMemo(() => {
    const normalizedSearch = search.toLowerCase();

    return subscribers.filter((subscriber) => {
      const status = normalizeText(
        subscriber.status ||
          subscriber.subscription_status ||
          subscriber.current_status
      );

      const platform = normalizeText(
        subscriber.store ||
          subscriber.platform ||
          subscriber.app_store ||
          subscriber.provider
      );

      const product = normalizeText(
        subscriber.product_id ||
          subscriber.provider_product_id ||
          subscriber.plan_name ||
          subscriber.plan?.name
      );

      const searchableText = [
        subscriber.id,
        subscriber.user_id,
        subscriber.email,
        subscriber.user_email,
        subscriber.customer_email,
        subscriber.first_name,
        subscriber.last_name,
        subscriber.name,
        subscriber.full_name,
        subscriber.product_id,
        subscriber.provider_product_id,
        subscriber.plan_name,
        subscriber.plan?.name,
        subscriber.status,
        subscriber.subscription_status,
        subscriber.store,
        subscriber.platform,
        subscriber.environment,
        subscriber.transaction_id,
        subscriber.original_transaction_id,
      ]
        .filter(Boolean)
        .join(" ")
        .toLowerCase();

      const matchesSearch = searchableText.includes(normalizedSearch);

      const matchesStatus =
        statusFilter === "All" ? true : status === statusFilter;

      const matchesPlatform =
        platformFilter === "All" ? true : platform === platformFilter;

      const matchesProduct =
        productFilter === "All" ? true : product === productFilter;

      return matchesSearch && matchesStatus && matchesPlatform && matchesProduct;
    });
  }, [subscribers, search, statusFilter, platformFilter, productFilter]);

  const totalPages = Math.max(
    1,
    Math.ceil(filteredSubscribers.length / SUBSCRIBERS_PER_PAGE)
  );

  const paginatedSubscribers = useMemo(() => {
    const startIndex = (currentPage - 1) * SUBSCRIBERS_PER_PAGE;

    return filteredSubscribers.slice(
      startIndex,
      startIndex + SUBSCRIBERS_PER_PAGE
    );
  }, [filteredSubscribers, currentPage]);

  useEffect(() => {
    setCurrentPage(1);
  }, [search, statusFilter, platformFilter, productFilter]);

  useEffect(() => {
    if (currentPage > totalPages) {
      setCurrentPage(totalPages);
    }
  }, [currentPage, totalPages]);

  const firstSubscriberIndex =
    filteredSubscribers.length === 0
      ? 0
      : (currentPage - 1) * SUBSCRIBERS_PER_PAGE + 1;

  const lastSubscriberIndex = Math.min(
    currentPage * SUBSCRIBERS_PER_PAGE,
    filteredSubscribers.length
  );

  return (
    <>
      <section
        style={{
          ...cardStyle,
          display: "grid",
          gap: 16,
        }}
      >
        <div>
          <h2 style={sectionTitleStyle}>Subscriber Filters</h2>
          <p style={sectionSubtextStyle}>
            Search and narrow the subscription list
          </p>
        </div>

        <div
          style={{
            display: "grid",
            gridTemplateColumns:
              "minmax(260px, 1.4fr) minmax(160px, 220px) minmax(160px, 220px) minmax(180px, 260px)",
            gap: 14,
          }}
        >
          <input
            type="text"
            placeholder="Search by name, email, product, transaction..."
            value={search}
            onChange={(event) => setSearch(event.target.value)}
            style={inputStyle}
          />

          <select
            value={statusFilter}
            onChange={(event) => setStatusFilter(event.target.value)}
            style={inputStyle}
          >
            <option value="All" style={optionStyle}>
              All Statuses
            </option>

            {statusOptions.map((status) => (
              <option key={status} value={status} style={optionStyle}>
                {titleize(status)}
              </option>
            ))}
          </select>

          <select
            value={platformFilter}
            onChange={(event) => setPlatformFilter(event.target.value)}
            style={inputStyle}
          >
            <option value="All" style={optionStyle}>
              All Platforms
            </option>

            {platformOptions.map((platform) => (
              <option key={platform} value={platform} style={optionStyle}>
                {titleize(platform)}
              </option>
            ))}
          </select>

          <select
            value={productFilter}
            onChange={(event) => setProductFilter(event.target.value)}
            style={inputStyle}
          >
            <option value="All" style={optionStyle}>
              All Products
            </option>

            {productOptions.map((product) => (
              <option key={product} value={product} style={optionStyle}>
                {titleize(product)}
              </option>
            ))}
          </select>
        </div>
      </section>

      <section style={cardStyle}>
        <Glow color="rgba(168,85,247,0.14)" />

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
            <h2 style={sectionTitleStyle}>Subscribers</h2>
            <p style={sectionSubtextStyle}>
              Showing {firstSubscriberIndex}-{lastSubscriberIndex} of{" "}
              {filteredSubscribers.length} subscribers
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
              onClick={() =>
                setCurrentPage((prev) => Math.min(totalPages, prev + 1))
              }
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

        {subscribersLoading ? (
          <div style={emptyStateStyle}>Loading subscribers...</div>
        ) : subscribersError ? (
          <div style={errorStateStyle}>{subscribersError}</div>
        ) : paginatedSubscribers.length > 0 ? (
          <div style={{ display: "grid", gap: 12 }}>
            {paginatedSubscribers.map((subscriber) => (
              <SubscriberRow
                key={
                  subscriber.id ||
                  subscriber.subscription_id ||
                  subscriber.user_id ||
                  subscriber.email
                }
                subscriber={subscriber}
              />
            ))}
          </div>
        ) : (
          <div style={emptyStateStyle}>
            No subscribers match your current filters.
          </div>
        )}
      </section>
    </>
  );
}

function SubscriberRow({ subscriber }) {
  const displayName = getSubscriberName(subscriber);

  const email =
    subscriber.email ||
    subscriber.user_email ||
    subscriber.customer_email ||
    subscriber.user?.email ||
    "—";

  const status = normalizeText(
    subscriber.status ||
      subscriber.subscription_status ||
      subscriber.current_status ||
      "unknown"
  );

  const platform = normalizeText(
    subscriber.store ||
      subscriber.platform ||
      subscriber.app_store ||
      subscriber.provider ||
      "—"
  );

  const product =
    subscriber.product_id ||
    subscriber.provider_product_id ||
    subscriber.plan_name ||
    subscriber.plan?.name ||
    "—";

  const amountCents =
    subscriber.price_cents ??
    subscriber.amount_cents ??
    subscriber.revenue_cents ??
    subscriber.price?.cents ??
    subscriber.price?.amount_cents ??
    subscriber.plan?.price_cents ??
    getFallbackPriceCents(product);

  const periodEnd =
    subscriber.current_period_end ||
    subscriber.expiration_at ||
    subscriber.expires_at ||
    subscriber.renewal_at;

  const isHealthy = ["active", "trialing", "trial", "paid"].includes(
    String(status).toLowerCase()
  );

  return (
    <div
      style={{
        display: "grid",
        gridTemplateColumns: subscriberRowGridTemplateColumns,
        columnGap: 18,
        alignItems: "center",
        width: "100%",
        padding: "14px 16px",
        borderRadius: 18,
        background: "rgba(255,255,255,0.04)",
        border: "1px solid rgba(255,255,255,0.06)",
        textAlign: "left",
        color: "inherit",
        position: "relative",
        overflow: "hidden",
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
          background: "linear-gradient(135deg, #a78bfa 0%, #67e8f9 100%)",
          boxShadow: "0 8px 18px rgba(167,139,250,0.16)",
          flexShrink: 0,
        }}
      >
        {getInitials(displayName, email)}
      </div>

      <div
        style={{
          minWidth: 0,
        }}
      >
        <div
          style={{
            fontWeight: 900,
            color: "#ffffff",
            whiteSpace: "nowrap",
            overflow: "hidden",
            textOverflow: "ellipsis",
          }}
        >
          {displayName}
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

      <MetaBlock label="Product" value={product} />
      <MetaBlock label="Platform" value={titleize(platform)} />
      <MetaBlock label="Renews / Ends" value={formatDateTime(periodEnd)} />

      <div
        style={{
          width: "100%",
          display: "grid",
          gap: 8,
          justifyItems: "end",
          alignContent: "center",
        }}
      >
        <span
          style={{
            minWidth: 116,
            padding: "7px 12px",
            borderRadius: 999,
            background: isHealthy
              ? "rgba(34,197,94,0.14)"
              : "rgba(239,68,68,0.14)",
            border: isHealthy
              ? "1px solid rgba(34,197,94,0.28)"
              : "1px solid rgba(239,68,68,0.28)",
            color: isHealthy ? "#86efac" : "#fca5a5",
            fontSize: "0.8rem",
            fontWeight: 900,
            textAlign: "center",
            boxSizing: "border-box",
          }}
        >
          {titleize(status)}
        </span>

        <span
          style={{
            width: "100%",
            color: "#dbeafe",
            fontSize: "0.82rem",
            fontWeight: 800,
            textAlign: "right",
          }}
        >
          {subscriber.price?.formatted || formatMoneyFromCents(amountCents)}
        </span>
      </div>
    </div>
  );
}

function MetaBlock({ label, value }) {
  return (
    <div
      style={{
        minWidth: 0,
        width: "100%",
      }}
    >
      <div
        style={{
          color: "#64748b",
          fontSize: "0.74rem",
          fontWeight: 900,
          textTransform: "uppercase",
          letterSpacing: "0.06em",
          marginBottom: 4,
        }}
      >
        {label}
      </div>

      <div
        style={{
          color: "#e2e8f0",
          fontSize: "0.9rem",
          fontWeight: 800,
          whiteSpace: "nowrap",
          overflow: "hidden",
          textOverflow: "ellipsis",
        }}
      >
        {value || "—"}
      </div>
    </div>
  );
}

function getSubscriberName(subscriber) {
  const firstName = subscriber.first_name || subscriber.user?.first_name || "";
  const lastName = subscriber.last_name || subscriber.user?.last_name || "";
  const fullName = `${firstName} ${lastName}`.trim();

  return (
    subscriber.name ||
    subscriber.full_name ||
    subscriber.user?.name ||
    fullName ||
    subscriber.email ||
    subscriber.user_email ||
    subscriber.customer_email ||
    "Unnamed Subscriber"
  );
}

function getInitials(name, email) {
  const safeName = String(name || "").trim();

  if (safeName && safeName !== "Unnamed Subscriber") {
    const pieces = safeName.split(" ").filter(Boolean);
    const first = pieces[0]?.[0] || "S";
    const last = pieces.length > 1 ? pieces[pieces.length - 1]?.[0] || "" : "";

    return `${first}${last}`.toUpperCase();
  }

  return String(email || "S").slice(0, 2).toUpperCase();
}

function buildUniqueOptions(items, selector) {
  const values = items
    .map(selector)
    .filter(Boolean)
    .filter((value) => value !== "—");

  return Array.from(new Set(values)).sort((a, b) => a.localeCompare(b));
}

function normalizeText(value) {
  if (value === null || value === undefined) return "";

  return String(value).trim();
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

function getFallbackPriceCents(product) {
  const normalizedProduct = String(product || "").toLowerCase();

  if (normalizedProduct.includes("moms_computer_monthly")) return 999;
  if (normalizedProduct.includes("moms_computer_yearly")) return 9999;

  return 0;
}