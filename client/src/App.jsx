import React from "react";
import { Routes, Route, Navigate } from "react-router-dom";
import PortalLayout from "./portal/PortalLayout";
import Dashboard from "./portal/pages/Dashboard";
import Login from "./portal/pages/Login";

export default function App() {
  return (
    <Routes>
      <Route path="/login" element={<Login />} />

      <Route path="/" element={<PortalLayout />}>
        <Route index element={<Dashboard />} />
      </Route>

      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}