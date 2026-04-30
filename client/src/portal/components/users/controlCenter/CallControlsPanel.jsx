import React, { useEffect, useState } from "react";
import {
  panelStyle,
  PanelHeader,
  MiniStat,
  ActionButton,
} from "./ControlCenterShared";

export default function CallControlsPanel({
  callCycle,
  actionLoading,
  runCallAction,
}) {
  const [monthlyLimit, setMonthlyLimit] = useState("");

  useEffect(() => {
    setMonthlyLimit(String(callCycle?.calls_allowed ?? 3));
  }, [callCycle]);

  const handleSetMonthlyLimit = () => {
    const parsedLimit = Number(monthlyLimit);

    if (!Number.isFinite(parsedLimit) || parsedLimit < 0) {
      window.alert("Monthly call limit must be 0 or greater.");
      return;
    }

    runCallAction("set_monthly_limit", {
      calls_allowed: parsedLimit,
    });
  };

  const adjustMonthlyLimit = (direction) => {
    const currentValue = Number(monthlyLimit || 0);
    const safeCurrentValue = Number.isFinite(currentValue) ? currentValue : 0;

    const nextValue =
      direction === "up"
        ? safeCurrentValue + 1
        : Math.max(safeCurrentValue - 1, 0);

    setMonthlyLimit(String(nextValue));
  };

  return (
    <div style={panelStyle}>
      <PanelHeader
        title="Support Call Controls"
        subtitle="Set this user's monthly support call allowance."
      />

      <div style={{ display: "grid", gap: 16 }}>
        <div
          style={{
            display: "grid",
            gridTemplateColumns: "repeat(auto-fit, minmax(160px, 1fr))",
            gap: 12,
          }}
        >
          <MiniStat
            label="Calls Allowed"
            value={String(callCycle?.calls_allowed ?? 3)}
            valueColor="#93c5fd"
          />

          <MiniStat
            label="Calls Used"
            value={String(callCycle?.calls_used ?? 0)}
            valueColor="#fcd34d"
          />
        </div>

        <div
          style={{
            display: "grid",
            gap: 10,
            maxWidth: 460,
          }}
        >
          <label
            htmlFor="monthly-call-limit"
            style={{
              color: "#cbd5e1",
              fontSize: "0.86rem",
              fontWeight: 900,
            }}
          >
            Set Monthly Call Limit
          </label>

          <div
            style={{
              display: "flex",
              gap: 10,
              flexWrap: "wrap",
              alignItems: "stretch",
            }}
          >
            <div style={numberInputShellStyle}>
              <input
                id="monthly-call-limit"
                className="user-control-input monthly-call-limit-input"
                type="number"
                min="0"
                value={monthlyLimit}
                onChange={(event) => setMonthlyLimit(event.target.value)}
                style={numberInputStyle}
              />

              <div style={arrowStackStyle}>
                <button
                  type="button"
                  onClick={() => adjustMonthlyLimit("up")}
                  disabled={Boolean(actionLoading)}
                  className="monthly-limit-arrow-button"
                  style={arrowButtonTopStyle}
                  aria-label="Increase monthly call limit"
                >
                  ▲
                </button>

                <button
                  type="button"
                  onClick={() => adjustMonthlyLimit("down")}
                  disabled={Boolean(actionLoading)}
                  className="monthly-limit-arrow-button"
                  style={arrowButtonBottomStyle}
                  aria-label="Decrease monthly call limit"
                >
                  ▼
                </button>
              </div>
            </div>

            <ActionButton
              label={
                actionLoading === "set_monthly_limit"
                  ? "Saving..."
                  : "Save Limit"
              }
              onClick={handleSetMonthlyLimit}
              disabled={Boolean(actionLoading)}
            />
          </div>
        </div>
      </div>

      <style>
        {`
          .monthly-call-limit-input::-webkit-outer-spin-button,
          .monthly-call-limit-input::-webkit-inner-spin-button {
            -webkit-appearance: none;
            margin: 0;
          }

          .monthly-call-limit-input[type="number"] {
            -moz-appearance: textfield;
          }

          .monthly-limit-arrow-button:hover:not(:disabled) {
            background: rgba(103, 232, 249, 0.16) !important;
            color: #e0faff !important;
          }

          .monthly-limit-arrow-button:active:not(:disabled) {
            transform: scale(0.96);
          }

          .monthly-limit-arrow-button:disabled {
            opacity: 0.45;
            cursor: not-allowed;
          }
        `}
      </style>
    </div>
  );
}

const numberInputShellStyle = {
  flex: "1 1 210px",
  minWidth: 0,
  display: "flex",
  alignItems: "stretch",
  borderRadius: 16,
  border: "1px solid rgba(255,255,255,0.12)",
  background:
    "linear-gradient(135deg, rgba(15,23,42,0.82), rgba(30,41,59,0.68))",
  overflow: "hidden",
  boxShadow:
    "inset 0 1px 0 rgba(255,255,255,0.05), 0 12px 26px rgba(0,0,0,0.16)",
};

const numberInputStyle = {
  flex: 1,
  minWidth: 0,
  border: "none",
  outline: "none",
  background: "transparent",
  color: "#ffffff",
  padding: "12px 14px",
  fontWeight: 950,
  fontSize: "1rem",
};

const arrowStackStyle = {
  width: 48,
  display: "grid",
  gridTemplateRows: "1fr 1fr",
  borderLeft: "1px solid rgba(255,255,255,0.10)",
  background: "rgba(2,6,23,0.28)",
};

const arrowButtonBaseStyle = {
  border: "none",
  background: "rgba(15,23,42,0.32)",
  color: "#93c5fd",
  fontSize: "1.05rem",
  fontWeight: 950,
  lineHeight: 1,
  cursor: "pointer",
  transition:
    "background 160ms ease, color 160ms ease, transform 120ms ease, opacity 160ms ease",
};

const arrowButtonTopStyle = {
  ...arrowButtonBaseStyle,
  borderBottom: "1px solid rgba(255,255,255,0.08)",
};

const arrowButtonBottomStyle = {
  ...arrowButtonBaseStyle,
};