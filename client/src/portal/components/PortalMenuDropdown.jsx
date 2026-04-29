import React, { useEffect, useMemo, useRef, useState } from "react";

const PANEL_OPTIONS = [
  {
    panelName: "users",
    label: "Users",
    emoji: "👥",
  },
  {
    panelName: "transactions",
    label: "Transaction Table",
    emoji: "💳",
  },
  {
    panelName: "subscribers",
    label: "Subscribers",
    emoji: "✅",
  },
  {
    panelName: "events",
    label: "Recent Events",
    emoji: "⚡",
  },
  {
    panelName: "debug",
    label: "Billing Debug",
    emoji: "🧪",
  },
];

const menuButtonStyle = {
  padding: "12px 16px",
  borderRadius: 14,
  border: "1px solid rgba(147,197,253,0.22)",
  background:
    "linear-gradient(135deg, rgba(59,130,246,0.16), rgba(168,85,247,0.12))",
  color: "#dbeafe",
  fontWeight: 900,
  cursor: "pointer",
  boxShadow: "0 12px 28px rgba(0,0,0,0.20)",
  display: "inline-flex",
  alignItems: "center",
  justifyContent: "center",
  gap: 8,
  minWidth: 180,
};

const dropdownStyle = {
  position: "absolute",
  right: 0,
  top: "calc(100% + 10px)",
  width: 285,
  padding: 10,
  borderRadius: 18,
  background: "rgba(15,23,42,0.98)",
  border: "1px solid rgba(255,255,255,0.12)",
  boxShadow: "0 24px 70px rgba(0,0,0,0.55)",
  backdropFilter: "blur(18px)",
  zIndex: 999999,
};

const itemStyle = {
  width: "100%",
  display: "flex",
  justifyContent: "space-between",
  alignItems: "center",
  gap: 10,
  padding: "12px 12px",
  borderRadius: 14,
  border: "1px solid transparent",
  background: "transparent",
  color: "#e2e8f0",
  fontWeight: 800,
  cursor: "pointer",
  textAlign: "left",
};

const activeItemStyle = {
  background: "rgba(59,130,246,0.16)",
  border: "1px solid rgba(147,197,253,0.22)",
  color: "#bfdbfe",
};

const logoutItemStyle = {
  ...itemStyle,
  color: "#fecaca",
};

export default function PortalMenuDropdown({ activePanel, onSelectPanel, onLogout }) {
  const [open, setOpen] = useState(false);
  const wrapperRef = useRef(null);

  const currentPanel = useMemo(() => {
    const normalizedActivePanel = activePanel === "overview" ? "users" : activePanel;

    return (
      PANEL_OPTIONS.find((option) => option.panelName === normalizedActivePanel) ||
      PANEL_OPTIONS[0]
    );
  }, [activePanel]);

  useEffect(() => {
    const handleDocumentClick = (event) => {
      if (!wrapperRef.current) return;

      if (!wrapperRef.current.contains(event.target)) {
        setOpen(false);
      }
    };

    document.addEventListener("mousedown", handleDocumentClick);

    return () => {
      document.removeEventListener("mousedown", handleDocumentClick);
    };
  }, []);

  const handleSelectPanel = (panelName) => {
    onSelectPanel(panelName);
    setOpen(false);
  };

  const renderPanelButton = ({ panelName, label, emoji }) => {
    const normalizedActivePanel = activePanel === "overview" ? "users" : activePanel;
    const isActive = normalizedActivePanel === panelName;

    return (
      <button
        type="button"
        onClick={() => handleSelectPanel(panelName)}
        style={{
          ...itemStyle,
          ...(isActive ? activeItemStyle : {}),
        }}
      >
        <span>
          {emoji} {label}
        </span>

        {isActive ? <span>●</span> : null}
      </button>
    );
  };

  return (
    <div ref={wrapperRef} style={{ position: "relative", zIndex: 999999 }}>
      <button
        type="button"
        onClick={() => setOpen((prev) => !prev)}
        style={menuButtonStyle}
      >
        <span>
          {currentPanel.emoji} {currentPanel.label}
        </span>
        <span>{open ? "▲" : "▼"}</span>
      </button>

      {open ? (
        <div style={dropdownStyle}>
          {PANEL_OPTIONS.map((option) => renderPanelButton(option))}

          <div
            style={{
              height: 1,
              background: "rgba(255,255,255,0.08)",
              margin: "8px 4px",
            }}
          />

          <button type="button" onClick={onLogout} style={logoutItemStyle}>
            <span>🚪 Logout</span>
          </button>
        </div>
      ) : null}
    </div>
  );
}