import React, { useEffect, useMemo, useState } from "react";
import Glow from "./Glow";
import {
  cardStyle,
  emptyStateStyle,
  errorStateStyle,
  inputStyle,
  sectionSubtextStyle,
  sectionTitleStyle,
} from "../styles/portalStyles";
import {
  formatDateTime,
  formatMoneyFromCents,
} from "../utils/portalFormatters";

export default function TransactionsPanel() {
  const [transactions, setTransactions] = useState([]);
  const [transactionsLoading, setTransactionsLoading] = useState(true);
  const [transactionsError, setTransactionsError] = useState("");
  const [search, setSearch] = useState("");

  useEffect(() => {
    const loadTransactions = async () => {
      try {
        console.log("[Portal Transactions] Starting transaction load...");

        setTransactionsLoading(true);
        setTransactionsError("");

        const token = localStorage.getItem("portalToken");

        const response = await fetch("/v1/admin/billing/transactions", {
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
          console.error("[Portal Transactions] JSON parse failed:", jsonError);
        }

        console.log("[Portal Transactions] Response status:", response.status);
        console.log("[Portal Transactions] Raw response data:", data);

        if (!response.ok) {
          throw new Error(
            data?.message ||
              data?.error ||
              "Failed to load transactions. Backend endpoint may not exist yet."
          );
        }

        const normalizedTransactions = Array.isArray(data)
          ? data
          : Array.isArray(data?.transactions)
          ? data.transactions
          : Array.isArray(data?.subscription_transactions)
          ? data.subscription_transactions
          : [];

        setTransactions(normalizedTransactions);
      } catch (err) {
        console.error("[Portal Transactions] Load error:", err);

        setTransactions([]);
        setTransactionsError(
          err.message || "Failed to load subscription transactions."
        );
      } finally {
        setTransactionsLoading(false);
      }
    };

    loadTransactions();
  }, []);

  const filteredTransactions = useMemo(() => {
    const normalizedSearch = search.toLowerCase();

    return transactions.filter((transaction) => {
      const searchableText = [
        transaction.id,
        transaction.user_id,
        transaction.email,
        transaction.customer_email,
        transaction.product_id,
        transaction.store,
        transaction.platform,
        transaction.event_type,
        transaction.transaction_id,
        transaction.revenuecat_transaction_id,
      ]
        .filter(Boolean)
        .join(" ")
        .toLowerCase();

      return searchableText.includes(normalizedSearch);
    });
  }, [transactions, search]);

  return (
    <section style={cardStyle}>
      <Glow color="rgba(168,85,247,0.14)" />

      <div
        style={{
          display: "flex",
          justifyContent: "space-between",
          alignItems: "flex-start",
          gap: 16,
          flexWrap: "wrap",
          marginBottom: 18,
        }}
      >
        <div>
          <h2 style={sectionTitleStyle}>Transaction Table</h2>
          <p style={sectionSubtextStyle}>
            RevenueCat-backed money events for accounting and subscription auditing.
          </p>
        </div>

        <div style={{ width: "min(100%, 360px)" }}>
          <input
            type="text"
            placeholder="Search transactions..."
            value={search}
            onChange={(event) => setSearch(event.target.value)}
            style={inputStyle}
          />
        </div>
      </div>

      {transactionsLoading ? (
        <div style={emptyStateStyle}>Loading transactions...</div>
      ) : transactionsError ? (
        <div style={errorStateStyle}>{transactionsError}</div>
      ) : filteredTransactions.length === 0 ? (
        <div style={emptyStateStyle}>No transactions found.</div>
      ) : (
        <div style={{ overflowX: "auto" }}>
          <table
            style={{
              width: "100%",
              borderCollapse: "separate",
              borderSpacing: "0 10px",
              minWidth: 900,
            }}
          >
            <thead>
              <tr>
                <TableHeader label="Date" />
                <TableHeader label="User" />
                <TableHeader label="Event" />
                <TableHeader label="Product" />
                <TableHeader label="Platform" />
                <TableHeader label="Amount" />
                <TableHeader label="Transaction ID" />
              </tr>
            </thead>

            <tbody>
              {filteredTransactions.map((transaction) => (
                <TransactionRow
                  key={
                    transaction.id ||
                    transaction.transaction_id ||
                    transaction.revenuecat_transaction_id
                  }
                  transaction={transaction}
                />
              ))}
            </tbody>
          </table>
        </div>
      )}
    </section>
  );
}

function TableHeader({ label }) {
  return (
    <th
      style={{
        padding: "0 12px 8px",
        color: "#94a3b8",
        fontSize: "0.78rem",
        fontWeight: 900,
        textTransform: "uppercase",
        letterSpacing: "0.08em",
        textAlign: "left",
        whiteSpace: "nowrap",
      }}
    >
      {label}
    </th>
  );
}

function TransactionRow({ transaction }) {
  const cents =
    transaction.price_cents ??
    transaction.amount_cents ??
    transaction.revenue_cents ??
    transaction.proceeds_cents ??
    0;

  const userLabel =
    transaction.email ||
    transaction.customer_email ||
    transaction.user_email ||
    (transaction.user_id ? `User #${transaction.user_id}` : "—");

  const eventLabel =
    transaction.event_type ||
    transaction.type ||
    transaction.revenuecat_event_type ||
    "—";

  const platformLabel =
    transaction.platform ||
    transaction.store ||
    transaction.app_store ||
    "—";

  const productLabel =
    transaction.product_id ||
    transaction.revenuecat_product_id ||
    transaction.entitlement_id ||
    "—";

  const transactionId =
    transaction.transaction_id ||
    transaction.revenuecat_transaction_id ||
    transaction.original_transaction_id ||
    "—";

  const createdAt =
    transaction.purchased_at ||
    transaction.event_at ||
    transaction.created_at ||
    transaction.updated_at;

  return (
    <tr>
      <td style={cellStyle}>{formatDateTime(createdAt)}</td>
      <td style={cellStyle}>{userLabel}</td>
      <td style={cellStyle}>
        <span
          style={{
            display: "inline-flex",
            padding: "7px 10px",
            borderRadius: 999,
            background: "rgba(59,130,246,0.12)",
            border: "1px solid rgba(147,197,253,0.18)",
            color: "#bfdbfe",
            fontWeight: 900,
            fontSize: "0.78rem",
          }}
        >
          {eventLabel}
        </span>
      </td>
      <td style={cellStyle}>{productLabel}</td>
      <td style={cellStyle}>{platformLabel}</td>
      <td style={cellStyle}>{formatMoneyFromCents(cents)}</td>
      <td style={cellStyle}>{transactionId}</td>
    </tr>
  );
}

const cellStyle = {
  padding: "14px 12px",
  background: "rgba(255,255,255,0.04)",
  borderTop: "1px solid rgba(255,255,255,0.06)",
  borderBottom: "1px solid rgba(255,255,255,0.06)",
  color: "#e2e8f0",
  fontSize: "0.88rem",
  fontWeight: 700,
  whiteSpace: "nowrap",
};