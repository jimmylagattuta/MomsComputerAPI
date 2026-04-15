import React from "react";
import { Outlet } from "react-router-dom";

export default function PortalLayout() {
  return (
    <div
      style={{
        minHeight: "100vh",
        color: "#ffffff",
        background:
          "radial-gradient(circle at top left, rgba(34,211,238,0.18), transparent 28%), radial-gradient(circle at top right, rgba(168,85,247,0.16), transparent 30%), radial-gradient(circle at bottom center, rgba(244,114,182,0.12), transparent 34%), linear-gradient(180deg, #020617 0%, #081225 42%, #0b1020 100%)",
        position: "relative",
        overflow: "hidden",
      }}
    >
      <div
        style={{
          position: "absolute",
          inset: 0,
          backgroundImage:
            "linear-gradient(rgba(255,255,255,0.03) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.03) 1px, transparent 1px)",
          backgroundSize: "34px 34px",
          opacity: 0.45,
          pointerEvents: "none",
        }}
      />

      <div
        style={{
          position: "absolute",
          top: -120,
          left: -80,
          width: 260,
          height: 260,
          borderRadius: "50%",
          background: "rgba(34,211,238,0.14)",
          filter: "blur(42px)",
          pointerEvents: "none",
        }}
      />

      <div
        style={{
          position: "absolute",
          top: 50,
          right: -60,
          width: 280,
          height: 280,
          borderRadius: "50%",
          background: "rgba(168,85,247,0.16)",
          filter: "blur(52px)",
          pointerEvents: "none",
        }}
      />

      <div
        style={{
          position: "absolute",
          bottom: -120,
          left: "50%",
          transform: "translateX(-50%)",
          width: 360,
          height: 360,
          borderRadius: "50%",
          background: "rgba(244,114,182,0.10)",
          filter: "blur(60px)",
          pointerEvents: "none",
        }}
      />

      <main
        style={{
          position: "relative",
          zIndex: 1,
          minHeight: "100vh",
        }}
      >
        <Outlet />
      </main>
    </div>
  );
}