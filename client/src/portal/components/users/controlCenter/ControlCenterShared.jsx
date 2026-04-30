import React from "react";

export const cardStyle = {
  position: "relative",
  overflow: "hidden",
  borderRadius: 24,
  padding: 0,
  background:
    "radial-gradient(circle at top right, rgba(168,85,247,0.18), transparent 28%), radial-gradient(circle at top left, rgba(34,211,238,0.14), transparent 26%), rgba(15, 23, 42, 0.78)",
  border: "1px solid rgba(255,255,255,0.10)",
  boxShadow: "0 20px 60px rgba(0,0,0,0.28)",
  backdropFilter: "blur(14px)",
};

export const panelStyle = {
  borderRadius: 22,
  background: "rgba(2, 6, 23, 0.56)",
  border: "1px solid rgba(255,255,255,0.08)",
  padding: 18,
};

export const buttonBaseStyle = {
  border: "none",
  borderRadius: 999,
  padding: "11px 16px",
  fontWeight: 900,
  cursor: "pointer",
  transition:
    "transform 0.18s ease, box-shadow 0.18s ease, border-color 0.18s ease, background 0.18s ease",
};

export const mutedTextStyle = {
  margin: 0,
  color: "#94a3b8",
  fontSize: "0.94rem",
  lineHeight: 1.55,
};

export const errorPanelStyle = {
  borderRadius: 18,
  padding: 16,
  border: "1px solid rgba(248,113,113,0.28)",
  background: "rgba(127,29,29,0.18)",
  color: "#fca5a5",
  fontWeight: 800,
};

export const successPanelStyle = {
  borderRadius: 18,
  padding: 16,
  border: "1px solid rgba(34,197,94,0.26)",
  background: "rgba(20,83,45,0.18)",
  color: "#86efac",
  fontWeight: 800,
};

export function PanelHeader({ title, subtitle }) {
  return (
    <div style={{ marginBottom: 16 }}>
      <h3
        style={{
          margin: 0,
          color: "#ffffff",
          fontSize: "1.15rem",
          fontWeight: 950,
          letterSpacing: "-0.02em",
        }}
      >
        {title}
      </h3>

      <p
        style={{
          margin: "6px 0 0",
          color: "#94a3b8",
          fontSize: "0.93rem",
          lineHeight: 1.55,
        }}
      >
        {subtitle}
      </p>
    </div>
  );
}

export function MiniStat({ label, value, valueColor = "#ffffff" }) {
  return (
    <div
      style={{
        borderRadius: 16,
        padding: 16,
        background: "rgba(255,255,255,0.04)",
        border: "1px solid rgba(255,255,255,0.08)",
        minWidth: 0,
      }}
    >
      <div
        style={{
          color: "#94a3b8",
          fontSize: "0.78rem",
          fontWeight: 800,
          marginBottom: 8,
          textTransform: "uppercase",
          letterSpacing: "0.04em",
        }}
      >
        {label}
      </div>

      <div
        style={{
          color: valueColor,
          fontSize: "1rem",
          fontWeight: 950,
          lineHeight: 1.35,
          wordBreak: "break-word",
        }}
      >
        {value || "—"}
      </div>
    </div>
  );
}

export function TabButton({ label, active, onClick }) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="user-control-tab"
      style={{
        ...buttonBaseStyle,
        background: active
          ? "linear-gradient(135deg, rgba(103,232,249,0.20), rgba(167,139,250,0.18))"
          : "rgba(255,255,255,0.04)",
        border: active
          ? "1px solid rgba(147,197,253,0.34)"
          : "1px solid rgba(255,255,255,0.08)",
        color: active ? "#ffffff" : "#cbd5e1",
        boxShadow: active ? "0 10px 24px rgba(103,232,249,0.08)" : "none",
      }}
    >
      {label}
    </button>
  );
}

export function ActionButton({ label, onClick, disabled = false, danger = false }) {
  return (
    <button
      type="button"
      onClick={onClick}
      disabled={disabled}
      className={
        danger ? "user-control-danger-button" : "user-control-secondary-button"
      }
      style={{
        ...buttonBaseStyle,
        border: danger
          ? "1px solid rgba(248,113,113,0.24)"
          : "1px solid rgba(147,197,253,0.24)",
        background: danger ? "rgba(127,29,29,0.18)" : "rgba(255,255,255,0.05)",
        color: danger ? "#fca5a5" : "#dbeafe",
        opacity: disabled ? 0.58 : 1,
        cursor: disabled ? "not-allowed" : "pointer",
      }}
    >
      {label}
    </button>
  );
}

export function Glow({
  color,
  top = "auto",
  left = "auto",
  right = "auto",
  bottom = "auto",
  size = 170,
}) {
  return (
    <div
      style={{
        position: "absolute",
        top,
        left,
        right,
        bottom,
        width: size,
        height: size,
        borderRadius: "50%",
        background: color,
        filter: "blur(38px)",
        pointerEvents: "none",
      }}
    />
  );
}

export function ComingSoonPanel({ title, subtitle, items }) {
  return (
    <div style={panelStyle}>
      <PanelHeader title={title} subtitle={subtitle} />

      <div
        style={{
          display: "grid",
          gridTemplateColumns: "repeat(auto-fit, minmax(220px, 1fr))",
          gap: 12,
        }}
      >
        {items.map((item) => (
          <div
            key={item}
            style={{
              borderRadius: 16,
              padding: 16,
              background: "rgba(255,255,255,0.04)",
              border: "1px solid rgba(255,255,255,0.08)",
              color: "#cbd5e1",
              fontWeight: 800,
              lineHeight: 1.4,
            }}
          >
            {item}
          </div>
        ))}
      </div>
    </div>
  );
}

export function formatDateTime(value) {
  if (!value) return "—";

  try {
    return new Date(value).toLocaleString("en-US", {
      year: "numeric",
      month: "short",
      day: "numeric",
      hour: "numeric",
      minute: "2-digit",
    });
  } catch (_err) {
    return "—";
  }
}

export function titleize(value) {
  if (!value) return "—";

  return String(value)
    .replace(/_/g, " ")
    .replace(/-/g, " ")
    .replace(/\s+/g, " ")
    .trim()
    .replace(/\w\S*/g, (word) => {
      if (word.length <= 3 && word === word.toUpperCase()) return word;
      return word.charAt(0).toUpperCase() + word.slice(1).toLowerCase();
    });
}