import React from "react";
import RevenueBlankPageShell, {
  RevenuePlaceholderCard,
} from "./RevenueBlankPageShell";

export default function RevenueForecastsPage() {
  return (
    <RevenueBlankPageShell
      emoji="🔮"
      title="Revenue Forecasts"
      subtitle="This section will project future revenue based on active subscribers, pricing, churn, failed payments, and growth assumptions."
    >
      <RevenuePlaceholderCard
        label="Next Month Estimate"
        value="Blank"
        subtext="Projected revenue if current subscribers renew."
        color="#67e8f9"
      />

      <RevenuePlaceholderCard
        label="Next 12 Months"
        value="Blank"
        subtext="Projected annual run-rate based on current MRR."
        color="#86efac"
      />

      <RevenuePlaceholderCard
        label="Churn Impact"
        value="Blank"
        subtext="Estimated revenue loss from cancellations or expirations."
        color="#fca5a5"
      />

      <RevenuePlaceholderCard
        label="Growth Scenario"
        value="Blank"
        subtext="Forecast if subscriber count grows month over month."
        color="#c4b5fd"
      />
    </RevenueBlankPageShell>
  );
}