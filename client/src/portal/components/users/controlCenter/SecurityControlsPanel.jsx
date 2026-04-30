import React from "react";
import { ComingSoonPanel } from "./ControlCenterShared";

export default function SecurityControlsPanel() {
  return (
    <ComingSoonPanel
      title="Security Controls"
      subtitle="Security tools should be added carefully with audit logging."
      items={[
        "Force password reset",
        "Revoke active sessions",
        "Review device list",
        "Audit suspicious account activity",
      ]}
    />
  );
}