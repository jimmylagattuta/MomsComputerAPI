import React, { useEffect, useMemo, useRef, useState } from "react";
import { useNavigate } from "react-router-dom";

import PortalHeader from "../components/PortalHeader";
import KpiGrid from "../components/KpiGrid";
import UsersPanel from "../components/UsersPanel";
import EmbeddedUserDetail from "../components/EmbeddedUserDetail";
import BillingDebugPanel from "../components/BillingDebugPanel";
import TransactionsPanel from "../components/TransactionsPanel";
import ActivePanelHeader from "../components/ActivePanelHeader";
import SubscribersPanel from "../components/SubscribersPanel";
import BillingIssuesPanel from "../components/BillingIssuesPanel";
import BillingIssueUserDetail from "../components/BillingIssueUserDetail";
import RevenueOverviewPanel from "../components/revenue/RevenueOverviewPanel";
import RecentEventsPanel from "../components/RecentEventsPanel";
import CancelledUsersPanel from "../components/CancelledUsersPanel";
import ExpiredUsersPanel from "../components/ExpiredUsersPanel";
import WebhookAuditPanel from "../components/WebhookAuditPanel";

export default function Dashboard() {
  const navigate = useNavigate();

  const usersTableRef = useRef(null);
  const currentMenuRef = useRef(null);
  const revenueCommandCenterRef = useRef(null);

  const [users, setUsers] = useState([]);
  const [usersLoading, setUsersLoading] = useState(true);
  const [usersError, setUsersError] = useState("");

  const [kpis, setKpis] = useState(null);
  const [kpisLoading, setKpisLoading] = useState(true);
  const [kpisError, setKpisError] = useState("");

  const [selectedUserId, setSelectedUserId] = useState(null);
  const [selectedBillingIssue, setSelectedBillingIssue] = useState(null);

  const [activePanel, setActivePanel] = useState("users");
  const [pendingScrollTarget, setPendingScrollTarget] = useState(null);

  const showActivePanelHeader = activePanel !== "revenue_overview";

  useEffect(() => {
    const token = localStorage.getItem("portalToken");

    if (!token) {
      navigate("/login", { replace: true });
    }
  }, [navigate]);

  useEffect(() => {
    const loadKpis = async () => {
      try {
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

  useEffect(() => {
    if (!pendingScrollTarget) return;

    let timeoutId = null;
    let frameOne = null;
    let frameTwo = null;

    frameOne = window.requestAnimationFrame(() => {
      frameTwo = window.requestAnimationFrame(() => {
        timeoutId = window.setTimeout(() => {
          if (pendingScrollTarget === "currentMenu") {
            if (activePanel === "subscribers" || activePanel === "billing_issues") {
              return;
            }

            scrollElementToTop(currentMenuRef.current, 0);
            setPendingScrollTarget(null);
            return;
          }

          if (pendingScrollTarget === "usersTable") {
            scrollElementToTop(usersTableRef.current, 24);
            setPendingScrollTarget(null);
            return;
          }

          if (pendingScrollTarget === "revenueCommandCenter") {
            if (activePanel === "revenue_overview") {
              return;
            }

            scrollElementToTop(revenueCommandCenterRef.current, 0);
            setPendingScrollTarget(null);
          }
        }, 250);
      });
    });

    return () => {
      if (frameOne) window.cancelAnimationFrame(frameOne);
      if (frameTwo) window.cancelAnimationFrame(frameTwo);
      if (timeoutId) window.clearTimeout(timeoutId);
    };
  }, [activePanel, pendingScrollTarget]);

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

  const goToMainPanel = () => {
    setSelectedUserId(null);
    setSelectedBillingIssue(null);
    setActivePanel("users");
    setPendingScrollTarget(null);

    window.requestAnimationFrame(() => {
      window.setTimeout(() => {
        window.scrollTo({
          top: 0,
          behavior: "smooth",
        });
      }, 50);
    });
  };

  const scrollToUsersTable = () => {
    setSelectedUserId(null);
    setSelectedBillingIssue(null);
    setActivePanel("users");
    setPendingScrollTarget("usersTable");
  };

  const goToSubscribersPanel = () => {
    setSelectedUserId(null);
    setSelectedBillingIssue(null);
    setActivePanel("subscribers");
    setPendingScrollTarget("currentMenu");
  };

  const goToBillingIssuesPanel = () => {
    setSelectedUserId(null);
    setSelectedBillingIssue(null);
    setActivePanel("billing_issues");
    setPendingScrollTarget("currentMenu");
  };

  const goToRevenueOverviewPanel = () => {
    setSelectedUserId(null);
    setSelectedBillingIssue(null);
    setActivePanel("revenue_overview");
    setPendingScrollTarget("revenueCommandCenter");

    if (activePanel === "revenue_overview") {
      window.requestAnimationFrame(() => {
        window.requestAnimationFrame(() => {
          scrollElementToTop(revenueCommandCenterRef.current, 0);
          setPendingScrollTarget(null);
        });
      });
    }
  };

  const handleSubscribersReady = () => {
    if (pendingScrollTarget !== "currentMenu") return;

    window.setTimeout(() => {
      scrollElementToTop(currentMenuRef.current, 0);
      setPendingScrollTarget(null);
    }, 80);
  };

  const handleBillingIssuesReady = () => {
    if (pendingScrollTarget !== "currentMenu") return;

    window.setTimeout(() => {
      scrollElementToTop(currentMenuRef.current, 0);
      setPendingScrollTarget(null);
    }, 80);
  };

  const handleRevenueOverviewReady = () => {
    if (pendingScrollTarget !== "revenueCommandCenter") return;

    window.setTimeout(() => {
      scrollElementToTop(revenueCommandCenterRef.current, 0);
      setPendingScrollTarget(null);
    }, 80);
  };

  const handleLogout = async () => {
    const token = localStorage.getItem("portalToken");

    try {
      if (token) {
        const response = await fetch("/v1/auth/logout", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${token}`,
          },
        });

        try {
          await response.json();
        } catch (jsonError) {
          console.error("[Portal Dashboard] Logout JSON parse failed:", jsonError);
        }
      }
    } catch (err) {
      console.error("[Portal Dashboard] Logout request failed:", err);
    } finally {
      localStorage.removeItem("portalToken");
      localStorage.removeItem("portalUser");

      navigate("/login", { replace: true });
    }
  };

  const handleSelectPanel = (panelName) => {
    setSelectedUserId(null);
    setSelectedBillingIssue(null);

    if (panelName === "overview") {
      setActivePanel("users");
      setPendingScrollTarget("currentMenu");
      return;
    }

    if (panelName === "revenue_overview") {
      setActivePanel("revenue_overview");
      setPendingScrollTarget("revenueCommandCenter");
      return;
    }

    setActivePanel(panelName);
    setPendingScrollTarget("currentMenu");
  };

  return (
    <div style={{ display: "grid", gap: 24 }}>
      <PortalHeader
        activePanel={activePanel}
        onSelectPanel={handleSelectPanel}
        onLogoClick={goToMainPanel}
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
        onMrrCardClick={goToRevenueOverviewPanel}
        onSubscriptionsCardClick={goToSubscribersPanel}
        onUsersCardClick={scrollToUsersTable}
        onBillingIssuesCardClick={goToBillingIssuesPanel}
      />

      {showActivePanelHeader ? (
        <div ref={currentMenuRef}>
          <ActivePanelHeader activePanel={activePanel} />
        </div>
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
          usersTableRef={usersTableRef}
          onSelectUser={(userId) => setSelectedUserId(userId)}
        />
      ) : null}

      {activePanel === "subscribers" ? (
        <SubscribersPanel onReady={handleSubscribersReady} />
      ) : null}

      {activePanel === "revenue_overview" ? (
        <div ref={revenueCommandCenterRef}>
          <RevenueOverviewPanel
            kpis={kpis}
            onReady={handleRevenueOverviewReady}
          />
        </div>
      ) : null}

      {activePanel === "transactions" ? <TransactionsPanel /> : null}

      {activePanel === "billing_issues" && selectedBillingIssue ? (
        <BillingIssueUserDetail
          billingIssue={selectedBillingIssue}
          onBack={() => setSelectedBillingIssue(null)}
        />
      ) : null}

      {activePanel === "billing_issues" && !selectedBillingIssue ? (
        <BillingIssuesPanel
          onReady={handleBillingIssuesReady}
          onSelectBillingIssue={(billingIssue) => {
            setSelectedUserId(null);
            setSelectedBillingIssue(billingIssue);
          }}
        />
      ) : null}

      {activePanel === "cancelled" ? <CancelledUsersPanel /> : null}

      {activePanel === "expired" ? <ExpiredUsersPanel /> : null}

      {activePanel === "events" ? <RecentEventsPanel /> : null}

      {activePanel === "webhook_audit" ? <WebhookAuditPanel /> : null}

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

function scrollElementToTop(element, offset = 0) {
  if (!element) return;

  const scrollParent = getScrollParent(element);

  if (scrollParent === window) {
    const elementTop = element.getBoundingClientRect().top + window.scrollY;

    window.scrollTo({
      top: Math.max(elementTop - offset, 0),
      behavior: "smooth",
    });

    return;
  }

  const parentRect = scrollParent.getBoundingClientRect();
  const elementRect = element.getBoundingClientRect();

  const nextScrollTop =
    scrollParent.scrollTop + elementRect.top - parentRect.top - offset;

  scrollParent.scrollTo({
    top: Math.max(nextScrollTop, 0),
    behavior: "smooth",
  });
}

function getScrollParent(element) {
  if (!element) return window;

  let parent = element.parentElement;

  while (parent) {
    const style = window.getComputedStyle(parent);
    const overflowY = style.overflowY;

    const canScroll =
      overflowY === "auto" ||
      overflowY === "scroll" ||
      overflowY === "overlay";

    if (canScroll && parent.scrollHeight > parent.clientHeight) {
      return parent;
    }

    parent = parent.parentElement;
  }

  return window;
}