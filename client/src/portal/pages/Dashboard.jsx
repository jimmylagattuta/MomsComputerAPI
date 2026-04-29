import React, { useEffect, useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";

import PortalHeader from "../components/PortalHeader";
import KpiGrid from "../components/KpiGrid";
import UsersPanel from "../components/UsersPanel";
import EmbeddedUserDetail from "../components/EmbeddedUserDetail";
import BillingDebugPanel from "../components/BillingDebugPanel";
import TransactionsPanel from "../components/TransactionsPanel";
import SimplePortalPanel from "../components/SimplePortalPanel";

export default function Dashboard() {
  const navigate = useNavigate();

  const [users, setUsers] = useState([]);
  const [usersLoading, setUsersLoading] = useState(true);
  const [usersError, setUsersError] = useState("");

  const [kpis, setKpis] = useState(null);
  const [kpisLoading, setKpisLoading] = useState(true);
  const [kpisError, setKpisError] = useState("");

  const [selectedUserId, setSelectedUserId] = useState(null);
  const [activePanel, setActivePanel] = useState("overview");

  useEffect(() => {
    const token = localStorage.getItem("portalToken");

    if (!token) {
      console.log("[Portal Dashboard] No portalToken found. Redirecting to login.");
      navigate("/login", { replace: true });
    }
  }, [navigate]);

  useEffect(() => {
    const loadKpis = async () => {
      try {
        console.log("[Portal Dashboard] Starting KPI load...");

        setKpisLoading(true);
        setKpisError("");

        const token = localStorage.getItem("portalToken");

        const response = await fetch("/v1/admin/billing/kpis", {
          method: "GET",
          headers: {
            "Content-Type": "application/json",
            ...(token ? { Authorization: `Bearer ${token}` } : {}),
          },
        });

        let data = null;

        try {
          data = await response.json();
        } catch (jsonError) {
          console.error("[Portal Dashboard] KPI JSON parse failed:", jsonError);
        }

        console.log("[Portal Dashboard] KPI response status:", response.status);
        console.log("[Portal Dashboard] KPI raw response data:", data);

        if (!response.ok) {
          throw new Error(
            data?.message || data?.error || "Failed to load billing KPIs."
          );
        }

        setKpis(data);
      } catch (err) {
        console.error("[Portal Dashboard] KPI load error:", err);

        setKpis(null);
        setKpisError(err.message || "Failed to load billing KPIs.");
      } finally {
        setKpisLoading(false);
      }
    };

    loadKpis();
  }, []);

  useEffect(() => {
    const loadUsers = async () => {
      try {
        console.log("[Portal Dashboard] Starting users load...");

        setUsersLoading(true);
        setUsersError("");

        const token = localStorage.getItem("portalToken");

        const response = await fetch("/v1/admin/users", {
          method: "GET",
          headers: {
            "Content-Type": "application/json",
            ...(token ? { Authorization: `Bearer ${token}` } : {}),
          },
        });

        let data = null;

        try {
          data = await response.json();
        } catch (jsonError) {
          console.error("[Portal Dashboard] Users JSON parse failed:", jsonError);
        }

        console.log("[Portal Dashboard] Users response status:", response.status);
        console.log("[Portal Dashboard] Users raw response data:", data);

        if (!response.ok) {
          throw new Error(data?.message || data?.error || "Failed to load users.");
        }

        const normalizedUsers = Array.isArray(data)
          ? data
          : Array.isArray(data?.users)
          ? data.users
          : [];

        setUsers(normalizedUsers);
      } catch (err) {
        console.error("[Portal Dashboard] Users load error:", err);

        setUsers([]);
        setUsersError(err.message || "Failed to load users.");
      } finally {
        setUsersLoading(false);
      }
    };

    loadUsers();
  }, []);

  const displayMrrCents = useMemo(() => {
    return Number(kpis?.mrr_cents || 0) > 0
      ? kpis?.mrr_cents
      : kpis?.revenue_this_month_cents;
  }, [kpis]);

  const displaySubscribers = useMemo(() => {
    return Number(kpis?.active_subscribers || 0) > 0
      ? kpis?.active_subscribers
      : kpis?.paying_users;
  }, [kpis]);

  const handleLogout = async () => {
    const token = localStorage.getItem("portalToken");

    console.log("[Portal Dashboard] Logout clicked.");
    console.log("[Portal Dashboard] portalToken exists?", Boolean(token));

    try {
      if (token) {
        const response = await fetch("/v1/auth/logout", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${token}`,
          },
        });

        let data = null;

        try {
          data = await response.json();
        } catch (jsonError) {
          console.error("[Portal Dashboard] Logout JSON parse failed:", jsonError);
        }

        console.log("[Portal Dashboard] Logout response status:", response.status);
        console.log("[Portal Dashboard] Logout response ok?", response.ok);
        console.log("[Portal Dashboard] Logout raw response data:", data);
      }
    } catch (err) {
      console.error("[Portal Dashboard] Logout request failed:", err);
    } finally {
      localStorage.removeItem("portalToken");
      localStorage.removeItem("portalUser");

      console.log("[Portal Dashboard] Portal token removed. Redirecting to login.");

      navigate("/login", { replace: true });
    }
  };

  const handleSelectPanel = (panelName) => {
    setSelectedUserId(null);
    setActivePanel(panelName);
  };

  return (
    <div style={{ display: "grid", gap: 24 }}>
      <PortalHeader
        activePanel={activePanel}
        onSelectPanel={handleSelectPanel}
        onLogout={handleLogout}
      />

      <KpiGrid
        kpis={kpis}
        kpisLoading={kpisLoading}
        kpisError={kpisError}
        usersLoading={usersLoading}
        totalUsers={users.length}
        displayMrrCents={displayMrrCents}
        displaySubscribers={displaySubscribers}
      />

      {activePanel === "overview" ? (
        <SimplePortalPanel
          title="Overview"
          subtitle="High-level portal summary."
          body="The KPI cards above are the main overview for revenue, users, subscriptions, and billing issues. This is the clean landing view for the client or tax attorney before drilling into users, transactions, subscribers, or RevenueCat events."
        />
      ) : null}

      {activePanel === "users" && selectedUserId ? (
        <EmbeddedUserDetail
          userId={selectedUserId}
          onBack={() => setSelectedUserId(null)}
        />
      ) : null}

      {activePanel === "users" && !selectedUserId ? (
        <UsersPanel
          users={users}
          usersLoading={usersLoading}
          usersError={usersError}
          onSelectUser={(userId) => setSelectedUserId(userId)}
        />
      ) : null}

      {activePanel === "transactions" ? <TransactionsPanel /> : null}

      {activePanel === "subscribers" ? (
        <SimplePortalPanel
          title="Subscribers"
          subtitle="Subscription status table coming next."
          body="This section is reserved for the subscriber table. It should eventually read from /v1/admin/billing/subscribers and show active, cancelled, expired, billing issue, trial, product, platform, and renewal data."
        />
      ) : null}

      {activePanel === "events" ? (
        <SimplePortalPanel
          title="Recent Events"
          subtitle="RevenueCat webhook audit trail coming next."
          body="This section is reserved for RevenueCat event history. It should eventually read from /v1/admin/billing/recent_events and show INITIAL_PURCHASE, RENEWAL, CANCELLATION, EXPIRATION, BILLING_ISSUE, and other webhook events."
        />
      ) : null}

      {activePanel === "debug" ? (
        <BillingDebugPanel
          kpis={kpis}
          kpisLoading={kpisLoading}
          kpisError={kpisError}
          displayMrrCents={displayMrrCents}
          displaySubscribers={displaySubscribers}
        />
      ) : null}
    </div>
  );
}