import React from "react";
import { cardStyle } from "../../styles/portalStyles";

const REVENUE_MENU_ITEMS = [
  {
    pageName: "snapshot",
    label: "Snapshot",
    emoji: "📊",
  },
  {
    pageName: "revenue_by_volume",
    label: "Activity Volume",
    emoji: "📈",
  },
  {
    pageName: "revenue_by_platform",
    label: "By Platform",
    emoji: "📱",
  },
  {
    pageName: "tax_export",
    label: "Tax / Export",
    emoji: "🧾",
  },
];

export default function RevenueNestedMenu({
  activeRevenuePage,
  onSelectRevenuePage,
}) {
  return (
    <section
      style={{
        ...cardStyle,
        padding: 14,
        display: "grid",
        gap: 12,
      }}
    >
      <div
        style={{
          display: "flex",
          justifyContent: "space-between",
          gap: 12,
          alignItems: "center",
          flexWrap: "wrap",
          padding: "2px 4px 0",
        }}
      >
        <div>
          <div
            style={{
              color: "#93c5fd",
              fontSize: "0.76rem",
              fontWeight: 950,
              textTransform: "uppercase",
              letterSpacing: "0.08em",
            }}
          >
            Revenue Workspace
          </div>
        </div>
      </div>

      <div
        style={{
          display: "grid",
          gridTemplateColumns: "repeat(auto-fit, minmax(170px, 1fr))",
          gap: 10,
        }}
      >
        {REVENUE_MENU_ITEMS.map((item) => {
          const isActive = activeRevenuePage === item.pageName;

          return (
            <button
              key={item.pageName}
              type="button"
              onClick={() => onSelectRevenuePage(item.pageName)}
              className="revenue-nested-menu-item"
              style={{
                minHeight: 70,
                borderRadius: 18,
                border: isActive
                  ? "1px solid rgba(147,197,253,0.34)"
                  : "1px solid rgba(255,255,255,0.08)",
                background: isActive
                  ? "linear-gradient(135deg, rgba(59,130,246,0.18), rgba(168,85,247,0.13))"
                  : "rgba(255,255,255,0.035)",
                color: isActive ? "#bfdbfe" : "#e2e8f0",
                cursor: "pointer",
                padding: "13px 14px",
                display: "flex",
                alignItems: "center",
                justifyContent: "space-between",
                gap: 10,
                textAlign: "left",
                boxShadow: isActive
                  ? "0 14px 32px rgba(59,130,246,0.12)"
                  : "none",
                transition:
                  "transform 0.18s ease, background 0.18s ease, border-color 0.18s ease, box-shadow 0.18s ease",
              }}
            >
              <span
                style={{
                  display: "flex",
                  alignItems: "center",
                  gap: 10,
                  minWidth: 0,
                }}
              >
                <span
                  style={{
                    width: 34,
                    height: 34,
                    borderRadius: 12,
                    display: "grid",
                    placeItems: "center",
                    background: "rgba(255,255,255,0.06)",
                    border: "1px solid rgba(255,255,255,0.07)",
                    flexShrink: 0,
                  }}
                >
                  {item.emoji}
                </span>

                <span
                  style={{
                    fontSize: "0.9rem",
                    fontWeight: 950,
                    whiteSpace: "nowrap",
                    overflow: "hidden",
                    textOverflow: "ellipsis",
                  }}
                >
                  {item.label}
                </span>
              </span>

              {isActive ? (
                <span
                  style={{
                    width: 9,
                    height: 9,
                    borderRadius: "50%",
                    background: "#93c5fd",
                    boxShadow: "0 0 16px rgba(147,197,253,0.65)",
                    flexShrink: 0,
                  }}
                />
              ) : null}
            </button>
          );
        })}
      </div>

      <style>
        {`
          .revenue-nested-menu-item:hover {
            transform: translateY(-2px);
            background: rgba(255,255,255,0.065) !important;
            border-color: rgba(147,197,253,0.22) !important;
            box-shadow: 0 14px 28px rgba(0,0,0,0.22) !important;
          }

          .revenue-nested-menu-item:active {
            transform: translateY(0);
          }

          .revenue-nested-menu-item:focus-visible {
            outline: 2px solid rgba(147,197,253,0.72);
            outline-offset: 3px;
          }
        `}
      </style>
    </section>
  );
}