import React from "react";
import { ComingSoonPanel } from "./ControlCenterShared";

export default function MessagingControlsPanel() {
  return (
    <ComingSoonPanel
      title="Messaging Controls"
      subtitle="Support texting and communication controls will live here."
      items={[
        "Enable or pause support texting",
        "Review open support threads",
        "Block abusive messaging",
        "Assign support ownership",
      ]}
    />
  );
}