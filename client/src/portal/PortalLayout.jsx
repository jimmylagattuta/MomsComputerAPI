import React from "react";
import { Outlet, Link } from "react-router-dom";

export default function PortalLayout() {
  return (
    <div style={{ minHeight: "100vh", background: "#111827", color: "#fff" }}>
      <header style={{ padding: "16px 24px", borderBottom: "1px solid #374151" }}>
        <h1 style={{ margin: 0 }}>Mom's Computer Portal</h1>

        <nav style={{ marginTop: 8 }}>
          <Link to="/" style={{ color: "#93c5fd", marginRight: 16 }}>
            Dashboard
          </Link>
          <Link to="/login" style={{ color: "#93c5fd" }}>
            Login
          </Link>
        </nav>
      </header>

      <main style={{ padding: 24 }}>
        <Outlet />
      </main>
    </div>
  );
}