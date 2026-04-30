import React from "react";
import RevenueBlankPageShell, {
  RevenuePlaceholderCard,
} from "./RevenueBlankPageShell";

export default function RevenueLifetimeValuePage() {
  return (
    <RevenueBlankPageShell
      emoji="💎"
      title="Lifetime Value"
      subtitle="This section will show lifetime revenue per user, high-value accounts, retention quality, and long-term subscriber value."
    >
      <RevenuePlaceholderCard
        label="Average LTV"
        value="Blank"
        subtext="Average lifetime revenue across all paying users."
        color="#67e8f9"
      />

      <RevenuePlaceholderCard
        label="Highest Value User"
        value="Blank"
        subtext="Top revenue-generating account."
        color="#86efac"
      />

      <RevenuePlaceholderCard
        label="Renewal Count"
        value="Blank"
        subtext="How many times users renew before cancelling or expiring."
        color="#c4b5fd"
      />

      <RevenuePlaceholderCard
        label="Retention Quality"
        value="Blank"
        subtext="Simple score based on renewal behavior and churn risk."
        color="#fcd34d"
      />
    </RevenueBlankPageShell>
  );
}