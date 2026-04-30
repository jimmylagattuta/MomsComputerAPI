import React from "react";
import RevenueBlankPageShell, {
  RevenuePlaceholderCard,
} from "./RevenueBlankPageShell";

export default function RevenueByProductPage() {
  return (
    <RevenueBlankPageShell
      emoji="📦"
      title="Revenue by Product"
      subtitle="This section will compare revenue across product IDs, monthly plans, yearly plans, future add-ons, and platform products."
    >
      <RevenuePlaceholderCard
        label="Monthly Plan"
        value="Blank"
        subtext="Revenue from the Mom's Computer monthly subscription."
        color="#67e8f9"
      />

      <RevenuePlaceholderCard
        label="Yearly Plan"
        value="Blank"
        subtext="Revenue from yearly subscription products once added."
        color="#86efac"
      />

      <RevenuePlaceholderCard
        label="Add-ons"
        value="Blank"
        subtext="Future revenue from extra calls, premium support, or add-on products."
        color="#c4b5fd"
      />

      <RevenuePlaceholderCard
        label="Product Mix"
        value="Blank"
        subtext="Which product types drive the most revenue."
        color="#fcd34d"
      />
    </RevenueBlankPageShell>
  );
}