import React from "react";
import RevenueBlankPageShell, {
  RevenuePlaceholderCard,
} from "./RevenueBlankPageShell";

export default function RevenueTaxExportPage({ kpis }) {
  const currentYear = new Date().getFullYear();

  return (
    <div style={{ display: "grid", gap: 22 }}>
      <RevenueBlankPageShell
        emoji="🧾"
        title="Tax / Export View"
        subtitle="A clean accounting and export area for monthly revenue, yearly revenue, total revenue, and tax-ready transaction records."
      >
        <RevenuePlaceholderCard
          label="Tax Export"
          value="Coming Soon"
          subtext="Export-ready revenue reports for the client, CPA, bookkeeper, or tax attorney."
          color="#c4b5fd"
        />

        <RevenuePlaceholderCard
          label={`${currentYear} Revenue`}
          value={formatMoneyFromCents(kpis?.revenue_this_year_cents)}
          subtext="Year-to-date subscription revenue currently tracked in the system."
          color="#fcd34d"
        />

        <RevenuePlaceholderCard
          label="This Month"
          value={formatMoneyFromCents(kpis?.revenue_this_month_cents)}
          subtext="Current month subscription revenue."
          color="#67e8f9"
        />

        <RevenuePlaceholderCard
          label="Total Revenue"
          value={formatMoneyFromCents(kpis?.total_revenue_cents)}
          subtext="All recorded subscription revenue."
          color="#86efac"
        />

        <RevenuePlaceholderCard
          label="Export Formats"
          value="CSV / PDF"
          subtext="Planned export options for accounting review."
          color="#93c5fd"
        />

        <RevenuePlaceholderCard
          label="Status"
          value="Not Built Yet"
          subtext="The UI placeholder is ready. Export generation can be wired later."
          color="#fca5a5"
        />
      </RevenueBlankPageShell>

      <section
        style={{
          borderRadius: 28,
          padding: "28px 30px",
          background:
            "radial-gradient(circle at top left, rgba(196,181,253,0.18), transparent 30%), radial-gradient(circle at top right, rgba(34,211,238,0.14), transparent 28%), rgba(15,23,42,0.82)",
          border: "1px solid rgba(196,181,253,0.20)",
          boxShadow: "0 22px 54px rgba(0,0,0,0.26)",
          overflow: "hidden",
          position: "relative",
        }}
      >
        <div
          style={{
            position: "absolute",
            right: -50,
            top: -60,
            width: 220,
            height: 220,
            borderRadius: "50%",
            background: "rgba(196,181,253,0.08)",
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
              background: "rgba(196,181,253,0.12)",
              border: "1px solid rgba(196,181,253,0.22)",
              color: "#ddd6fe",
              fontSize: "0.78rem",
              fontWeight: 950,
              textTransform: "uppercase",
              letterSpacing: "0.08em",
              marginBottom: 14,
            }}
          >
            🧾 Coming Soon
          </div>

          <h3
            style={{
              margin: 0,
              color: "#ffffff",
              fontSize: "clamp(2rem, 5vw, 4rem)",
              fontWeight: 950,
              letterSpacing: "-0.08em",
              lineHeight: 0.98,
            }}
          >
            Tax / Export Center
          </h3>

          <p
            style={{
              margin: "14px 0 0",
              color: "#cbd5e1",
              fontSize: "1rem",
              lineHeight: 1.65,
              maxWidth: 820,
              fontWeight: 750,
            }}
          >
            This page will eventually produce clean monthly, yearly, and all-time
            revenue exports. For now, the important revenue totals are displayed
            above, and the export workflow can be built when the portal is ready
            for accounting access.
          </p>
        </div>
      </section>

      <section
        style={{
          display: "grid",
          gridTemplateColumns: "repeat(auto-fit, minmax(240px, 1fr))",
          gap: 14,
        }}
      >
        <ComingSoonCard
          eyebrow="Planned"
          title="Monthly Revenue Export"
          description="CSV or PDF export grouped by month, platform, product, and transaction type."
          color="#67e8f9"
        />

        <ComingSoonCard
          eyebrow="Planned"
          title="Year-End Tax Summary"
          description="A clean annual revenue summary for the client, CPA, or tax attorney."
          color="#fcd34d"
        />

        <ComingSoonCard
          eyebrow="Planned"
          title="Transaction Audit Trail"
          description="Exportable list of purchases, renewals, cancellations, and RevenueCat event references."
          color="#86efac"
        />

        <ComingSoonCard
          eyebrow="Planned"
          title="Platform Breakdown"
          description="App Store vs Google Play totals for monthly, yearly, and all-time revenue."
          color="#c4b5fd"
        />
      </section>
    </div>
  );
}

function ComingSoonCard({ eyebrow, title, description, color }) {
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
        {eyebrow}
      </div>

      <h4
        style={{
          margin: "8px 0 0",
          color: "#ffffff",
          fontSize: "1.05rem",
          fontWeight: 950,
          letterSpacing: "-0.03em",
        }}
      >
        {title}
      </h4>

      <p
        style={{
          margin: "9px 0 0",
          color: "#94a3b8",
          fontSize: "0.9rem",
          lineHeight: 1.55,
          fontWeight: 700,
        }}
      >
        {description}
      </p>
    </div>
  );
}

function formatMoneyFromCents(value) {
  const cents = Number(value || 0);

  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
  }).format(cents / 100);
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