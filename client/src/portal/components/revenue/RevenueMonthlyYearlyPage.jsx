import React from "react";
import RevenueBlankPageShell, {
  RevenuePlaceholderCard,
} from "./RevenueBlankPageShell";

export default function RevenueMonthlyYearlyPage() {
  return (
    <RevenueBlankPageShell
      emoji="📅"
      title="Monthly / Yearly Revenue"
      subtitle="This section will compare monthly revenue, yearly revenue, MRR, current month totals, current year totals, and renewal performance."
    >
      <RevenuePlaceholderCard
        label="Current Month"
        value="Blank"
        subtext="Revenue collected in the current calendar month."
        color="#67e8f9"
      />

      <RevenuePlaceholderCard
        label="Current Year"
        value="Blank"
        subtext="Revenue collected in the current calendar year."
        color="#86efac"
      />

      <RevenuePlaceholderCard
        label="Monthly Trend"
        value="Blank"
        subtext="Month-over-month subscription revenue trend."
        color="#c4b5fd"
      />

      <RevenuePlaceholderCard
        label="Yearly Trend"
        value="Blank"
        subtext="Year-over-year subscription revenue performance."
        color="#fcd34d"
      />
    </RevenueBlankPageShell>
  );
}