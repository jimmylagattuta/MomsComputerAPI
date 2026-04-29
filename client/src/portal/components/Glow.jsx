import React from "react";

export default function Glow({ color }) {
  return (
    <div
      style={{
        position: "absolute",
        top: -30,
        right: -30,
        width: 120,
        height: 120,
        borderRadius: "50%",
        background: color,
        filter: "blur(30px)",
        pointerEvents: "none",
      }}
    />
  );
}