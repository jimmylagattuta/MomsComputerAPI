import React from "react";
import { ComingSoonPanel } from "./ControlCenterShared";

export default function AccessControlsPanel() {
  return (
    <ComingSoonPanel
      title="Access Controls"
      subtitle="Subscription, entitlement, and access override tools will live here."
      items={[
        "Grant temporary access",
        "Review entitlement state",
        "Handle subscription overrides",
        "Prepare RevenueCat/Rails reconciliation",
      ]}
    />
  );
}