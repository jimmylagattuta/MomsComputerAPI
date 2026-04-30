import React, { useEffect, useRef, useState } from "react";
import {
  cardStyle,
  buttonBaseStyle,
  errorPanelStyle,
  successPanelStyle,
  mutedTextStyle,
  Glow,
  TabButton,
} from "./ControlCenterShared";
import CallControlsPanel from "./CallControlsPanel";
import AccountControlsPanel from "./AccountControlsPanel";
import MessagingControlsPanel from "./MessagingControlsPanel";
import AccessControlsPanel from "./AccessControlsPanel";
import SecurityControlsPanel from "./SecurityControlsPanel";

export default function UserControlCenter({ userId, user: initialUser }) {
  const [isOpen, setIsOpen] = useState(false);
  const [activeTab, setActiveTab] = useState("calls");
  const [payload, setPayload] = useState(null);
  const [loading, setLoading] = useState(false);
  const [actionLoading, setActionLoading] = useState("");

  const [error, setError] = useState("");
  const [successMessage, setSuccessMessage] = useState("");
  const [flashFading, setFlashFading] = useState(false);

  const flashPersistTimerRef = useRef(null);
  const flashFadeTimerRef = useRef(null);

  const displayUser = payload?.user || initialUser;

  const userLabel = buildUserLabel(displayUser, userId);
  const shortUserLabel = buildShortUserLabel(displayUser, userId);

  useEffect(() => {
    if (!isOpen || !userId) return;

    loadControlCenter();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isOpen, userId]);

  useEffect(() => {
    return () => {
      clearFlashTimers();
    };
  }, []);

  const clearFlashTimers = () => {
    if (flashPersistTimerRef.current) {
      clearTimeout(flashPersistTimerRef.current);
      flashPersistTimerRef.current = null;
    }

    if (flashFadeTimerRef.current) {
      clearTimeout(flashFadeTimerRef.current);
      flashFadeTimerRef.current = null;
    }
  };

  const clearFlashMessages = () => {
    clearFlashTimers();
    setError("");
    setSuccessMessage("");
    setFlashFading(false);
  };

  const showSuccessFlash = (message) => {
    clearFlashTimers();
    setError("");
    setSuccessMessage(message);
    setFlashFading(false);

    flashPersistTimerRef.current = setTimeout(() => {
      setFlashFading(true);

      flashFadeTimerRef.current = setTimeout(() => {
        setSuccessMessage("");
        setFlashFading(false);
      }, 650);
    }, 3500);
  };

  const showErrorFlash = (message) => {
    clearFlashTimers();
    setSuccessMessage("");
    setError(message);
    setFlashFading(false);

    flashPersistTimerRef.current = setTimeout(() => {
      setFlashFading(true);

      flashFadeTimerRef.current = setTimeout(() => {
        setError("");
        setFlashFading(false);
      }, 650);
    }, 4500);
  };

  const loadControlCenter = async () => {
    try {
      setLoading(true);
      clearFlashMessages();

      const token = localStorage.getItem("portalToken");

      const response = await fetch(`/v1/admin/users/${userId}/control_center`, {
        method: "GET",
        headers: {
          "Content-Type": "application/json",
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
      });

      let data = null;

      try {
        data = await response.json();
      } catch (_err) {
        data = null;
      }

      if (!response.ok) {
        throw new Error(
          data?.message || data?.error || "Failed to load user controls."
        );
      }

      setPayload(data);
    } catch (err) {
      console.error("[UserControlCenter] Load failed:", err);
      showErrorFlash(err.message || "Failed to load user controls.");
      setPayload(null);
    } finally {
      setLoading(false);
    }
  };

  const runCallAction = async (actionType, extraParams = {}) => {
    try {
      setActionLoading(actionType);
      clearFlashMessages();

      const token = localStorage.getItem("portalToken");

      const response = await fetch(`/v1/admin/users/${userId}/control_calls`, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
        body: JSON.stringify({
          action_type: actionType,
          ...extraParams,
        }),
      });

      let data = null;

      try {
        data = await response.json();
      } catch (_err) {
        data = null;
      }

      if (!response.ok) {
        throw new Error(
          data?.message || data?.error || "Failed to update call controls."
        );
      }

      setPayload((previous) => ({
        ...(previous || {}),
        user: data?.user || previous?.user || initialUser || null,
        current_call_cycle:
          data?.current_call_cycle || previous?.current_call_cycle || null,
      }));

      showSuccessFlash(
        data?.message || `${shortUserLabel}’s call controls were updated.`
      );
    } catch (err) {
      console.error("[UserControlCenter] Action failed:", err);
      showErrorFlash(
        err.message || `Failed to update controls for ${shortUserLabel}.`
      );
    } finally {
      setActionLoading("");
    }
  };

  const renderActivePanel = () => {
    if (loading) {
      return (
        <div style={loadingPanelStyle}>
          <p style={mutedTextStyle}>
            Loading control center for {userLabel}...
          </p>
        </div>
      );
    }

    if (!payload) {
      return null;
    }

    if (activeTab === "calls") {
      return (
        <CallControlsPanel
          user={payload.user}
          userLabel={userLabel}
          shortUserLabel={shortUserLabel}
          callCycle={payload.current_call_cycle}
          actionLoading={actionLoading}
          runCallAction={runCallAction}
        />
      );
    }

    if (activeTab === "account") {
      return (
        <AccountControlsPanel
          user={payload.user}
          userLabel={userLabel}
          shortUserLabel={shortUserLabel}
        />
      );
    }

    if (activeTab === "messaging") {
      return (
        <MessagingControlsPanel
          user={payload.user}
          userLabel={userLabel}
          shortUserLabel={shortUserLabel}
        />
      );
    }

    if (activeTab === "access") {
      return (
        <AccessControlsPanel
          user={payload.user}
          userLabel={userLabel}
          shortUserLabel={shortUserLabel}
        />
      );
    }

    if (activeTab === "security") {
      return (
        <SecurityControlsPanel
          user={payload.user}
          userLabel={userLabel}
          shortUserLabel={shortUserLabel}
        />
      );
    }

    return null;
  };

  return (
    <section style={cardStyle}>
      <Glow color="rgba(103,232,249,0.16)" top={-60} left={-40} size={190} />
      <Glow color="rgba(168,85,247,0.14)" right={-50} bottom={-70} size={220} />

      <div
        style={{
          position: "relative",
          padding: 22,
          display: "grid",
          gap: 16,
        }}
      >
        <div
          style={{
            display: "flex",
            justifyContent: "space-between",
            alignItems: "center",
            gap: 16,
            flexWrap: "wrap",
          }}
        >
          <div>
            <div style={eyebrowStyle}>Admin Tools for {shortUserLabel}</div>

            <h2
              style={{
                margin: "10px 0 4px",
                color: "#ffffff",
                fontSize: "1.55rem",
                fontWeight: 950,
                letterSpacing: "-0.035em",
              }}
            >
              User Control Center — {userLabel}
            </h2>

            <p
              style={{
                margin: 0,
                color: "#94a3b8",
                fontSize: "0.96rem",
                lineHeight: 1.55,
              }}
            >
              Open the control panel to manage calls, account settings,
              messaging, access, and security for {userLabel}.
            </p>
          </div>

          <button
            type="button"
            onClick={() => setIsOpen((current) => !current)}
            className="user-control-center-main-button"
            style={{
              ...buttonBaseStyle,
              color: "#081120",
              background: "linear-gradient(135deg, #67e8f9 0%, #a78bfa 100%)",
              boxShadow:
                "0 16px 34px rgba(103,232,249,0.18), 0 0 24px rgba(167,139,250,0.14)",
              minWidth: 190,
            }}
          >
            {isOpen ? "Close Controls ↑" : "Open Controls ↓"}
          </button>
        </div>

        {isOpen ? (
          <div style={{ display: "grid", gap: 16 }}>
            <div style={{ display: "flex", gap: 10, flexWrap: "wrap" }}>
              <TabButton
                label="Calls"
                active={activeTab === "calls"}
                onClick={() => setActiveTab("calls")}
              />
            </div>

            {error ? (
              <div
                style={{
                  ...errorPanelStyle,
                  ...flashPanelStyle,
                  ...(flashFading ? flashPanelFadingStyle : {}),
                }}
              >
                {error}
              </div>
            ) : null}

            {successMessage ? (
              <div
                style={{
                  ...successPanelStyle,
                  ...flashPanelStyle,
                  ...(flashFading ? flashPanelFadingStyle : {}),
                }}
              >
                {successMessage}
              </div>
            ) : null}

            {renderActivePanel()}
          </div>
        ) : null}
      </div>

      <style>
        {`
          .user-control-center-main-button:hover,
          .user-control-tab:hover,
          .user-control-secondary-button:hover,
          .user-control-danger-button:hover {
            transform: translateY(-1px);
          }

          .user-control-center-main-button:hover {
            box-shadow: 0 20px 42px rgba(103,232,249,0.24), 0 0 28px rgba(167,139,250,0.20) !important;
          }

          .user-control-input:focus {
            outline: none;
            border-color: rgba(103,232,249,0.58) !important;
            box-shadow: 0 0 0 4px rgba(103,232,249,0.10);
          }
        `}
      </style>
    </section>
  );
}

function buildUserLabel(user, userId) {
  if (!user) return `User #${userId}`;

  const fullName = [user.first_name, user.last_name]
    .filter(Boolean)
    .join(" ")
    .trim();

  if (fullName && user.email) return `${fullName} — ${user.email}`;
  if (fullName) return fullName;
  if (user.name && user.email) return `${user.name} — ${user.email}`;
  if (user.name) return user.name;
  if (user.email) return user.email;

  return `User #${user.id || userId}`;
}

function buildShortUserLabel(user, userId) {
  if (!user) return `User #${userId}`;

  const fullName = [user.first_name, user.last_name]
    .filter(Boolean)
    .join(" ")
    .trim();

  if (fullName) return fullName;
  if (user.name) return user.name;
  if (user.email) return user.email;

  return `User #${user.id || userId}`;
}

const eyebrowStyle = {
  display: "inline-flex",
  alignItems: "center",
  gap: 8,
  padding: "7px 12px",
  borderRadius: 999,
  background: "rgba(255,255,255,0.06)",
  border: "1px solid rgba(255,255,255,0.08)",
  color: "#93c5fd",
  fontSize: "0.78rem",
  fontWeight: 900,
  textTransform: "uppercase",
  letterSpacing: "0.05em",
};

const loadingPanelStyle = {
  borderRadius: 22,
  background: "rgba(2, 6, 23, 0.56)",
  border: "1px solid rgba(255,255,255,0.08)",
  padding: 18,
};

const flashPanelStyle = {
  transition:
    "opacity 650ms ease, transform 650ms ease, max-height 650ms ease, margin 650ms ease, padding 650ms ease",
  opacity: 1,
  transform: "translateY(0)",
  overflow: "hidden",
};

const flashPanelFadingStyle = {
  opacity: 0,
  transform: "translateY(-6px)",
};