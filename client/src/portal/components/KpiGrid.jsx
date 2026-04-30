import React from "react";
import StatCard from "./StatCard";
import { formatMoneyFromCents, formatNumber } from "../utils/portalFormatters";

export default function KpiGrid({
  kpis,
  kpisLoading,
  kpisError,
  usersLoading,
  totalUsers,
  displayMrrCents,
  displaySubscribers,
  onMrrCardClick,
  onSubscriptionsCardClick,
  onUsersCardClick,
  onBillingIssuesCardClick,
}) {
  return (
    <section
      style={{
        display: "grid",
        gridTemplateColumns: "repeat(auto-fit, minmax(220px, 1fr))",
        gap: 18,
      }}
    >
      <StatCard
        title="MRR"
        value={
          kpisLoading
            ? "..."
            : kpisError
            ? "Error"
            : formatMoneyFromCents(displayMrrCents)
        }
        subtext="Monthly recurring revenue"
        glow="rgba(34,211,238,0.18)"
        onClick={onMrrCardClick}
      />

      <StatCard
        title="Subscriptions"
        value={
          kpisLoading
            ? "..."
            : kpisError
            ? "Error"
            : formatNumber(displaySubscribers)
        }
        subtext="Click to view subscribers"
        glow="rgba(168,85,247,0.18)"
        onClick={onSubscriptionsCardClick}
      />

      <StatCard
        title="Users"
        value={
          kpisLoading
            ? "..."
            : kpisError
            ? usersLoading
              ? "..."
              : String(totalUsers)
            : formatNumber(kpis?.total_users)
        }
        subtext="Click to jump to users table"
        glow="rgba(244,114,182,0.18)"
        onClick={onUsersCardClick}
      />

      <StatCard
        title="Billing Issues"
        value={
          kpisLoading
            ? "..."
            : kpisError
            ? "Error"
            : formatNumber(kpis?.billing_issue_subscribers)
        }
        subtext="Accounts needing attention"
        glow="rgba(250,204,21,0.16)"
        onClick={onBillingIssuesCardClick}
      />
    </section>
  );
}