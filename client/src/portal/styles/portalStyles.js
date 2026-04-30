export const cardStyle = {
  position: "relative",
  overflow: "hidden",
  borderRadius: 24,
  padding: 24,
  background: "rgba(15, 23, 42, 0.78)",
  border: "1px solid rgba(255,255,255,0.10)",
  boxShadow: "0 20px 60px rgba(0,0,0,0.28)",
  backdropFilter: "blur(14px)",
};

export const statCardStyle = {
  ...cardStyle,
  minHeight: 150,
  display: "flex",
  flexDirection: "column",
  justifyContent: "space-between",
};

export const labelStyle = {
  display: "inline-flex",
  alignItems: "center",
  gap: 8,
  padding: "8px 14px",
  borderRadius: 999,
  background: "rgba(255,255,255,0.06)",
  border: "1px solid rgba(255,255,255,0.09)",
  fontSize: "0.82rem",
  fontWeight: 700,
  color: "#dbeafe",
  width: "fit-content",
};

export const sectionTitleStyle = {
  margin: 0,
  fontSize: "1.15rem",
  fontWeight: 800,
  letterSpacing: "-0.02em",
  color: "#ffffff",
};

export const sectionSubtextStyle = {
  margin: "6px 0 0",
  color: "#94a3b8",
  fontSize: "0.95rem",
};

export const inputStyle = {
  width: "100%",
  padding: "14px 16px",
  borderRadius: "16px",
  border: "1px solid rgba(255,255,255,0.12)",
  background: "rgba(255,255,255,0.05)",
  color: "#ffffff",
  outline: "none",
  fontSize: "0.96rem",
  boxSizing: "border-box",
};

export const pageButtonStyle = {
  border: "1px solid rgba(255,255,255,0.10)",
  borderRadius: 12,
  minWidth: 44,
  height: 44,
  padding: 0,
  fontWeight: 900,
  fontSize: "1rem",
  color: "#e2e8f0",
  background: "rgba(255,255,255,0.05)",
};

export const pageIndicatorStyle = {
  padding: "10px 14px",
  borderRadius: 12,
  border: "1px solid rgba(255,255,255,0.08)",
  background: "rgba(255,255,255,0.04)",
  color: "#cbd5e1",
  fontSize: "0.9rem",
  fontWeight: 700,
};

export const emptyStateStyle = {
  padding: "28px 20px",
  borderRadius: 18,
  background: "rgba(255,255,255,0.04)",
  border: "1px solid rgba(255,255,255,0.06)",
  color: "#cbd5e1",
  fontWeight: 700,
};

export const errorStateStyle = {
  padding: "28px 20px",
  borderRadius: 18,
  background: "rgba(239,68,68,0.12)",
  border: "1px solid rgba(248,113,113,0.25)",
  color: "#fecaca",
  fontWeight: 700,
};

export const infoGridStyle = {
  display: "grid",
  gap: 2,
};

export const backButtonStyle = {
  width: "fit-content",
  padding: "10px 14px",
  borderRadius: 12,
  border: "1px solid rgba(147,197,253,0.22)",
  background: "rgba(59,130,246,0.08)",
  color: "#93c5fd",
  fontWeight: 800,
  cursor: "pointer",
};

export const glowingMenuPillStyle = {
  display: "inline-flex",
  alignItems: "center",
  justifyContent: "center",
  gap: 8,
  padding: "10px 14px",
  borderRadius: 999,
  border: "1px solid rgba(103,232,249,0.48)",
  background:
    "linear-gradient(135deg, rgba(34,211,238,0.28), rgba(96,165,250,0.22), rgba(168,85,247,0.24))",
  color: "#ffffff",
  fontWeight: 900,
  fontSize: "0.82rem",
  letterSpacing: "0.01em",
  boxShadow:
    "0 0 0 1px rgba(103,232,249,0.10), 0 12px 30px rgba(0,0,0,0.30), 0 0 24px rgba(103,232,249,0.16)",
  backdropFilter: "blur(14px)",
};