import React, { useEffect, useRef, useState } from "react";
import { createPortal } from "react-dom";

const PANEL_GROUPS = [
  {
    groupLabel: "Core",
    options: [
      {
        panelName: "users",
        label: "Users",
        emoji: "👥",
      },
      {
        panelName: "subscribers",
        label: "Subscribers",
        emoji: "✅",
      },
    ],
  },
  {
    groupLabel: "Revenue",
    options: [
      {
        panelName: "revenue_overview",
        label: "Revenue Overview",
        emoji: "📊",
      },
      {
        panelName: "transactions",
        label: "Transaction Table",
        emoji: "💳",
      },
    ],
  },
  {
    groupLabel: "Subscription Health",
    options: [
      {
        panelName: "billing_issues",
        label: "Billing Issues",
        emoji: "⚠️",
      },
      {
        panelName: "cancelled",
        label: "Cancelled Users",
        emoji: "🛑",
      },
      {
        panelName: "expired",
        label: "Expired Users",
        emoji: "⌛",
      },
    ],
  },
  {
    groupLabel: "Audit / Debug",
    options: [
      {
        panelName: "events",
        label: "Recent Events",
        emoji: "⚡",
      },
      {
        panelName: "webhook_audit",
        label: "Webhook Audit Log",
        emoji: "🧾",
      },
      {
        panelName: "debug",
        label: "Billing Debug",
        emoji: "🔧",
      },
    ],
  },
];

const menuButtonStyle = {
  padding: "14px 18px",
  borderRadius: 16,
  border: "1px solid rgba(103,232,249,0.52)",
  background:
    "linear-gradient(135deg, rgba(34,211,238,0.34), rgba(96,165,250,0.28), rgba(168,85,247,0.30))",
  color: "#ffffff",
  fontWeight: 950,
  fontSize: "1rem",
  cursor: "pointer",
  boxShadow:
    "0 0 0 1px rgba(103,232,249,0.12), 0 18px 44px rgba(0,0,0,0.46), 0 0 34px rgba(103,232,249,0.22)",
  backdropFilter: "blur(16px)",
  display: "inline-flex",
  alignItems: "center",
  justifyContent: "center",
  gap: 8,
  minWidth: 170,
  transition:
    "transform 0.18s ease, box-shadow 0.18s ease, border-color 0.18s ease",
};

const dropdownStyle = {
  position: "absolute",
  right: 0,
  top: "calc(100% + 12px)",
  width: "min(650px, calc(100vw - 28px))",
  maxHeight: "min(76vh, 720px)",
  overflowY: "auto",
  padding: 14,
  borderRadius: 24,
  background:
    "radial-gradient(circle at top left, rgba(59,130,246,0.14), transparent 34%), radial-gradient(circle at bottom right, rgba(168,85,247,0.12), transparent 34%), rgba(15,23,42,0.98)",
  border: "1px solid rgba(255,255,255,0.12)",
  boxShadow: "0 28px 80px rgba(0,0,0,0.62)",
  backdropFilter: "blur(18px)",
  zIndex: 999999,
};

const headerStyle = {
  display: "flex",
  justifyContent: "space-between",
  alignItems: "center",
  gap: 12,
  padding: "4px 4px 12px",
  borderBottom: "1px solid rgba(255,255,255,0.08)",
  marginBottom: 12,
};

const eyebrowStyle = {
  color: "#93c5fd",
  fontSize: "0.72rem",
  fontWeight: 900,
  textTransform: "uppercase",
  letterSpacing: "0.09em",
};

const titleStyle = {
  marginTop: 4,
  color: "#ffffff",
  fontSize: "1.05rem",
  fontWeight: 950,
  letterSpacing: "-0.03em",
};

const hintStyle = {
  color: "#94a3b8",
  fontSize: "0.78rem",
  fontWeight: 700,
  textAlign: "right",
};

const groupGridStyle = {
  display: "grid",
  gridTemplateColumns: "repeat(2, minmax(0, 1fr))",
  gap: 12,
};

const groupCardStyle = {
  position: "relative",
  overflow: "hidden",
  borderRadius: 20,
  padding: 10,
  background: "rgba(255,255,255,0.035)",
  border: "1px solid rgba(255,255,255,0.08)",
};

const groupLabelStyle = {
  position: "relative",
  zIndex: 1,
  padding: "4px 4px 10px",
  color: "#dbeafe",
  fontSize: "0.72rem",
  fontWeight: 950,
  textTransform: "uppercase",
  letterSpacing: "0.09em",
  display: "flex",
  alignItems: "center",
  justifyContent: "space-between",
  gap: 8,
};

const countPillStyle = {
  padding: "3px 7px",
  borderRadius: 999,
  background: "rgba(255,255,255,0.06)",
  border: "1px solid rgba(255,255,255,0.08)",
  color: "#94a3b8",
  fontSize: "0.68rem",
  fontWeight: 900,
};

const itemStyle = {
  width: "100%",
  display: "flex",
  justifyContent: "space-between",
  alignItems: "center",
  gap: 10,
  padding: "11px 12px",
  borderRadius: 15,
  border: "1px solid transparent",
  background: "transparent",
  color: "#e2e8f0",
  fontWeight: 800,
  cursor: "pointer",
  textAlign: "left",
  transition:
    "transform 0.18s ease, background 0.18s ease, border-color 0.18s ease, box-shadow 0.18s ease",
};

const activeItemStyle = {
  background: "rgba(59,130,246,0.16)",
  border: "1px solid rgba(147,197,253,0.24)",
  color: "#bfdbfe",
  boxShadow: "0 12px 26px rgba(59,130,246,0.10)",
};

const itemMainStyle = {
  display: "flex",
  alignItems: "center",
  gap: 9,
  minWidth: 0,
};

const emojiStyle = {
  width: 30,
  height: 30,
  borderRadius: 11,
  display: "grid",
  placeItems: "center",
  background: "rgba(255,255,255,0.06)",
  border: "1px solid rgba(255,255,255,0.07)",
  flexShrink: 0,
};

const itemLabelStyle = {
  color: "inherit",
  fontSize: "0.88rem",
  fontWeight: 900,
  whiteSpace: "nowrap",
  overflow: "hidden",
  textOverflow: "ellipsis",
};

const activeDotStyle = {
  width: 9,
  height: 9,
  borderRadius: "50%",
  background: "#93c5fd",
  boxShadow: "0 0 16px rgba(147,197,253,0.65)",
  flexShrink: 0,
};

const footerStyle = {
  display: "flex",
  justifyContent: "space-between",
  alignItems: "center",
  gap: 12,
  marginTop: 12,
  paddingTop: 12,
  borderTop: "1px solid rgba(255,255,255,0.08)",
};

const footerTextStyle = {
  color: "#64748b",
  fontSize: "0.76rem",
  fontWeight: 800,
};

const logoutItemStyle = {
  padding: "11px 14px",
  borderRadius: 14,
  border: "1px solid rgba(248,113,113,0.18)",
  background: "rgba(239,68,68,0.08)",
  color: "#fecaca",
  fontWeight: 900,
  cursor: "pointer",
  whiteSpace: "nowrap",
};

export default function PortalMenuDropdown({
  activePanel,
  onSelectPanel,
  onLogout,
}) {
  const [open, setOpen] = useState(false);
  const [isFloating, setIsFloating] = useState(false);
  const [buttonBox, setButtonBox] = useState({
    width: 170,
    height: 52,
  });

  const anchorRef = useRef(null);
  const normalWrapperRef = useRef(null);
  const floatingWrapperRef = useRef(null);
  const normalButtonRef = useRef(null);

  useEffect(() => {
    const handleDocumentClick = (event) => {
      const normalWrapper = normalWrapperRef.current;
      const floatingWrapper = floatingWrapperRef.current;

      const clickedNormal =
        normalWrapper && normalWrapper.contains(event.target);

      const clickedFloating =
        floatingWrapper && floatingWrapper.contains(event.target);

      if (!clickedNormal && !clickedFloating) {
        setOpen(false);
      }
    };

    document.addEventListener("mousedown", handleDocumentClick);

    return () => {
      document.removeEventListener("mousedown", handleDocumentClick);
    };
  }, []);

  useEffect(() => {
    let frameId = null;

    const updateFloatingState = () => {
      if (frameId) {
        window.cancelAnimationFrame(frameId);
      }

      frameId = window.requestAnimationFrame(() => {
        const anchor = anchorRef.current;
        const normalButton = normalButtonRef.current;

        if (normalButton) {
          const rect = normalButton.getBoundingClientRect();

          setButtonBox({
            width: Math.ceil(rect.width || 170),
            height: Math.ceil(rect.height || 52),
          });
        }

        if (!anchor) return;

        const anchorRect = anchor.getBoundingClientRect();
        setIsFloating(anchorRect.top <= 86);
      });
    };

    updateFloatingState();

    document.addEventListener("scroll", updateFloatingState, true);
    window.addEventListener("scroll", updateFloatingState, { passive: true });
    window.addEventListener("resize", updateFloatingState);

    return () => {
      if (frameId) {
        window.cancelAnimationFrame(frameId);
      }

      document.removeEventListener("scroll", updateFloatingState, true);
      window.removeEventListener("scroll", updateFloatingState);
      window.removeEventListener("resize", updateFloatingState);
    };
  }, []);

  const handleSelectPanel = (panelName) => {
    onSelectPanel(panelName);
    setOpen(false);
  };

  const renderPanelButton = ({ panelName, label, emoji }) => {
    const normalizedActivePanel =
      activePanel === "overview" ? "users" : activePanel;
    const isActive = normalizedActivePanel === panelName;

    return (
      <button
        type="button"
        key={panelName}
        onClick={() => handleSelectPanel(panelName)}
        className="portal-menu-item"
        style={{
          ...itemStyle,
          ...(isActive ? activeItemStyle : {}),
        }}
      >
        <span style={itemMainStyle}>
          <span style={emojiStyle}>{emoji}</span>
          <span style={itemLabelStyle}>{label}</span>
        </span>

        {isActive ? <span style={activeDotStyle} /> : null}
      </button>
    );
  };

  const dropdownContent = (
    <div style={dropdownStyle}>
      <div style={headerStyle}>
        <div>
          <div style={eyebrowStyle}>Navigation</div>
          <div style={titleStyle}>Portal Menu</div>
        </div>

        <div style={hintStyle}>Admin sections</div>
      </div>

      <div
        className="portal-menu-dropdown-force-single-column"
        style={groupGridStyle}
      >
        {PANEL_GROUPS.map((group) => (
          <div key={group.groupLabel} style={groupCardStyle}>
            <div
              style={{
                position: "absolute",
                inset: 0,
                background:
                  "radial-gradient(circle at top right, rgba(147,197,253,0.10), transparent 44%)",
                pointerEvents: "none",
              }}
            />

            <div style={groupLabelStyle}>
              <span>{group.groupLabel}</span>
              <span style={countPillStyle}>{group.options.length}</span>
            </div>

            <div
              style={{
                position: "relative",
                zIndex: 1,
                display: "grid",
                gap: 6,
              }}
            >
              {group.options.map((option) => renderPanelButton(option))}
            </div>
          </div>
        ))}
      </div>

      <div style={footerStyle}>
        <div style={footerTextStyle}>Choose a section or sign out.</div>

        <button type="button" onClick={onLogout} style={logoutItemStyle}>
          🚪 Logout
        </button>
      </div>
    </div>
  );

  const renderMenuButton = (ref = null) => (
    <button
      ref={ref}
      type="button"
      onClick={() => setOpen((prev) => !prev)}
      className="portal-menu-main-button"
      style={menuButtonStyle}
    >
      Portal Menu {open ? "▲" : "▼"}
    </button>
  );

  const floatingMenu =
    isFloating && typeof document !== "undefined"
      ? createPortal(
          <div
            ref={floatingWrapperRef}
            style={{
              position: "fixed",
              top: 16,
              right: 18,
              zIndex: 999999,
              animation: "portalMenuFloatIn 180ms ease-out",
            }}
          >
            {renderMenuButton()}
            {open ? dropdownContent : null}
          </div>,
          document.body
        )
      : null;

  return (
    <>
      <div
        ref={anchorRef}
        style={{
          position: "relative",
          zIndex: 999999,
          width: isFloating ? buttonBox.width : "auto",
          height: isFloating ? buttonBox.height : "auto",
          minWidth: isFloating ? buttonBox.width : "auto",
        }}
      >
        {!isFloating ? (
          <div
            ref={normalWrapperRef}
            style={{
              position: "relative",
              zIndex: 999999,
            }}
          >
            {renderMenuButton(normalButtonRef)}
            {open ? dropdownContent : null}
          </div>
        ) : null}
      </div>

      {floatingMenu}

      <style>
        {`
          .portal-menu-item:hover {
            transform: translateY(-2px);
            background: rgba(255,255,255,0.065) !important;
            border-color: rgba(147,197,253,0.20) !important;
            box-shadow: 0 14px 28px rgba(0,0,0,0.22) !important;
          }

          .portal-menu-item:active {
            transform: translateY(0);
          }

          .portal-menu-main-button:hover {
            transform: translateY(-1px);
            box-shadow:
              0 0 0 1px rgba(103,232,249,0.16),
              0 22px 52px rgba(0,0,0,0.48),
              0 0 42px rgba(103,232,249,0.24) !important;
          }

          .portal-menu-item:focus-visible,
          .portal-menu-main-button:focus-visible {
            outline: 2px solid rgba(147,197,253,0.72);
            outline-offset: 3px;
          }

          @keyframes portalMenuFloatIn {
            from {
              opacity: 0;
              transform: translateY(-6px) scale(0.98);
            }

            to {
              opacity: 1;
              transform: translateY(0) scale(1);
            }
          }

          @media (max-width: 720px) {
            .portal-menu-dropdown-force-single-column {
              grid-template-columns: 1fr !important;
            }
          }
        `}
      </style>
    </>
  );
}