import React from "react";

export default function UserRow({
  initials,
  name,
  email,
  role,
  status,
  createdAt,
  onClick,
}) {
  const isEnabled = status === "Enabled";

  return (
    <>
      <button
        type="button"
        onClick={onClick}
        className="portal-user-row"
        style={{
          display: "grid",
          gridTemplateColumns: "auto 1fr auto auto",
          gap: 14,
          alignItems: "center",
          width: "100%",
          padding: "14px 16px",
          borderRadius: 18,
          background: "rgba(255,255,255,0.04)",
          border: "1px solid rgba(255,255,255,0.06)",
          textAlign: "left",
          cursor: "pointer",
          color: "inherit",
          position: "relative",
          overflow: "hidden",
          transition:
            "transform 0.24s ease, border-color 0.24s ease, box-shadow 0.24s ease, background 0.24s ease",
        }}
      >
        <span
          className="portal-user-row-shine"
          style={{
            position: "absolute",
            top: 0,
            left: "-35%",
            width: "32%",
            height: "100%",
            background:
              "linear-gradient(90deg, rgba(255,255,255,0) 0%, rgba(103,232,249,0.18) 50%, rgba(255,255,255,0) 100%)",
            transform: "skewX(-20deg)",
            pointerEvents: "none",
          }}
        />

        <div
          className="portal-user-row-avatar"
          style={{
            width: 44,
            height: 44,
            borderRadius: "50%",
            display: "grid",
            placeItems: "center",
            fontWeight: 900,
            color: "#081120",
            background: "linear-gradient(135deg, #67e8f9 0%, #a78bfa 100%)",
            boxShadow: "0 8px 18px rgba(103,232,249,0.14)",
            transition: "transform 0.24s ease, box-shadow 0.24s ease",
          }}
        >
          {initials}
        </div>

        <div
          className="portal-user-row-main"
          style={{
            minWidth: 0,
            transition: "transform 0.24s ease",
          }}
        >
          <div
            style={{
              fontWeight: 800,
              color: "#ffffff",
              whiteSpace: "nowrap",
              overflow: "hidden",
              textOverflow: "ellipsis",
            }}
          >
            {name}
          </div>

          <div
            style={{
              color: "#94a3b8",
              fontSize: "0.92rem",
              whiteSpace: "nowrap",
              overflow: "hidden",
              textOverflow: "ellipsis",
              marginTop: 2,
            }}
          >
            {email}
          </div>
        </div>

        <div
          className="portal-user-row-meta"
          style={{
            textAlign: "right",
            transition: "transform 0.24s ease",
          }}
        >
          <div
            style={{
              padding: "7px 12px",
              borderRadius: 999,
              background: "rgba(255,255,255,0.06)",
              border: "1px solid rgba(255,255,255,0.08)",
              color: "#dbeafe",
              fontSize: "0.8rem",
              fontWeight: 700,
              display: "inline-block",
            }}
          >
            {role}
          </div>

          <div
            style={{
              color: "#94a3b8",
              fontSize: "0.82rem",
              marginTop: 6,
            }}
          >
            {createdAt}
          </div>
        </div>

        <span
          style={{
            padding: "7px 12px",
            borderRadius: 999,
            background: isEnabled
              ? "rgba(34,197,94,0.14)"
              : "rgba(239,68,68,0.14)",
            border: isEnabled
              ? "1px solid rgba(34,197,94,0.28)"
              : "1px solid rgba(239,68,68,0.28)",
            color: isEnabled ? "#86efac" : "#fca5a5",
            fontSize: "0.8rem",
            fontWeight: 800,
            transition: "transform 0.24s ease",
          }}
        >
          {status}
        </span>
      </button>

      <style>
        {`
          .portal-user-row:hover {
            transform: translateY(-4px) scale(1.008);
            background: rgba(255,255,255,0.07);
            border-color: rgba(103,232,249,0.32);
            box-shadow:
              0 20px 40px rgba(0,0,0,0.34),
              0 0 0 1px rgba(103,232,249,0.08),
              0 0 28px rgba(103,232,249,0.10);
          }

          .portal-user-row:hover .portal-user-row-shine {
            animation: portalUserRowShine 0.85s ease;
          }

          .portal-user-row:hover .portal-user-row-avatar {
            transform: scale(1.08) rotate(-4deg);
            box-shadow:
              0 12px 24px rgba(103,232,249,0.20),
              0 0 18px rgba(167,139,250,0.18);
          }

          .portal-user-row:hover .portal-user-row-main,
          .portal-user-row:hover .portal-user-row-meta {
            transform: translateX(3px);
          }

          @keyframes portalUserRowShine {
            0% {
              left: -35%;
            }
            100% {
              left: 120%;
            }
          }
        `}
      </style>
    </>
  );
}