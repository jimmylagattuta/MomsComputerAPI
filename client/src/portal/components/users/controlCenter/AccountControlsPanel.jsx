import React from "react";
import { ComingSoonPanel } from "./ControlCenterShared";

export default function AccountControlsPanel() {
  return (
    <ComingSoonPanel
      title="Account Controls"
      subtitle="Account-level controls will live here once we wire the next backend actions."
      items={[
        "Edit account status",
        "Update account flags",
        "Add internal admin notes",
        "Review account lifecycle history",
      ]}
    />
  );
}