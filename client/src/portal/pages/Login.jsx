import React, { useMemo, useState } from "react";

const LOGO_URL =
  "https://res.cloudinary.com/djtsuktwb/image/upload/v1769703507/ChatGPT_Image_Jan_29_2026_08_00_07_AM_1_3_gtqeo8.jpg";

export default function Login() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState("");

  const canSubmit = useMemo(() => {
    return email.trim() && password.trim() && !isLoading;
  }, [email, password, isLoading]);

  const extractErrorMessage = (data, response) => {
    const raw =
      (typeof data === "string" && data) ||
      data?.error ||
      data?.message ||
      (Array.isArray(data?.details) && data.details[0]) ||
      (Array.isArray(data?.errors) && data.errors[0]) ||
      "";

    if (raw === "invalid_credentials" || response?.status === 401) {
      return "Incorrect email or password.";
    }

    if (raw === "validation_error") {
      if (Array.isArray(data?.details) && data.details.length > 0) {
        return data.details[0];
      }
      return "Please check your information and try again.";
    }

    if (raw === "bad_request" || response?.status === 400) {
      return "The sign-in request could not be processed.";
    }

    if (raw === "missing_token") {
      return "Your session token was missing. Please try again.";
    }

    if (raw === "invalid_token") {
      return "Your session is invalid. Please sign in again.";
    }

    if (typeof raw === "string" && raw.trim()) {
      return raw.replaceAll("_", " ");
    }

    return "Sign in failed. Please check your email and password.";
  };

  const handleSubmit = async (e) => {
    e.preventDefault();

    if (isLoading) return;

    const trimmedEmail = email.trim().toLowerCase();
    const trimmedPassword = password.trim();

    if (!trimmedEmail || !trimmedPassword) {
      setError("Please enter your email and password.");
      return;
    }

    setError("");
    setIsLoading(true);

    try {
      const response = await fetch("/v1/auth/login", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          user: {
            email: trimmedEmail,
            password: trimmedPassword,
          },
        }),
      });

      let data = null;
      try {
        data = await response.json();
      } catch (_jsonError) {
        data = null;
      }

      if (!response.ok) {
        throw new Error(extractErrorMessage(data, response));
      }

      if (!data?.token) {
        throw new Error("Login succeeded, but no token was returned.");
      }

      localStorage.setItem("portalToken", data.token);

      if (data.user) {
        localStorage.setItem("portalUser", JSON.stringify(data.user));
      }

      window.location.href = "/portal/dashboard";
    } catch (err) {
      setError(err.message || "Something went wrong while signing in.");
      setIsLoading(false);
    }
  };

  return (
    <div
      style={{
        minHeight: "100vh",
        display: "grid",
        placeItems: "center",
        padding: "24px",
      }}
    >
      <div
        style={{
          width: "100%",
          maxWidth: "460px",
          borderRadius: "30px",
          padding: "34px 28px",
          background:
            "linear-gradient(180deg, rgba(15,23,42,0.88) 0%, rgba(15,23,42,0.78) 100%)",
          border: "1px solid rgba(255,255,255,0.10)",
          boxShadow:
            "0 24px 80px rgba(0,0,0,0.38), 0 0 0 1px rgba(255,255,255,0.03)",
          backdropFilter: "blur(16px)",
          textAlign: "center",
          position: "relative",
          overflow: "hidden",
        }}
      >
        <div
          style={{
            position: "absolute",
            top: "-70px",
            right: "-70px",
            width: "180px",
            height: "180px",
            borderRadius: "50%",
            background: "rgba(34,211,238,0.12)",
            filter: "blur(36px)",
            pointerEvents: "none",
          }}
        />

        <div
          style={{
            position: "absolute",
            bottom: "-80px",
            left: "-60px",
            width: "200px",
            height: "200px",
            borderRadius: "50%",
            background: "rgba(168,85,247,0.14)",
            filter: "blur(42px)",
            pointerEvents: "none",
          }}
        />

        <div style={{ position: "relative", zIndex: 1 }}>
          <div
            style={{
              width: "110px",
              height: "110px",
              margin: "0 auto 18px",
              borderRadius: "24px",
              padding: "10px",
              background: "rgba(255,255,255,0.06)",
              border: "1px solid rgba(255,255,255,0.10)",
              boxShadow: "0 12px 40px rgba(0,0,0,0.28)",
              display: "grid",
              placeItems: "center",
            }}
          >
            <img
              src={LOGO_URL}
              alt="Mom's Computer logo"
              style={{
                width: "100%",
                height: "100%",
                objectFit: "contain",
                borderRadius: "18px",
                display: "block",
              }}
            />
          </div>

          <div
            style={{
              display: "inline-flex",
              alignItems: "center",
              justifyContent: "center",
              gap: "8px",
              padding: "8px 14px",
              borderRadius: "999px",
              background: "rgba(255,255,255,0.06)",
              border: "1px solid rgba(255,255,255,0.08)",
              fontSize: "0.8rem",
              fontWeight: 800,
              color: "#67e8f9",
              marginBottom: "16px",
            }}
          >
            Secure Admin Access
          </div>

          <h1
            style={{
              margin: "0 0 8px",
              fontSize: "2rem",
              fontWeight: 900,
              letterSpacing: "-0.03em",
              lineHeight: 1.05,
            }}
          >
            Welcome Back
          </h1>

          <p
            style={{
              margin: "0 0 24px",
              color: "#cbd5e1",
              lineHeight: 1.6,
              fontSize: "0.98rem",
            }}
          >
            Sign in to access the Mom&apos;s Computer admin portal.
          </p>

          <form onSubmit={handleSubmit} style={{ display: "grid", gap: "14px" }}>
            <input
              type="email"
              placeholder="Email"
              style={inputStyle}
              autoComplete="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              disabled={isLoading}
            />

            <input
              type="password"
              placeholder="Password"
              style={inputStyle}
              autoComplete="current-password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              disabled={isLoading}
            />

            {error ? <div style={errorStyle}>{error}</div> : null}

            <button
              type="submit"
              disabled={!canSubmit}
              style={{
                ...buttonStyle,
                opacity: canSubmit ? 1 : 0.72,
                cursor: canSubmit ? "pointer" : "not-allowed",
                position: "relative",
                overflow: "hidden",
              }}
            >
              {isLoading && (
                <span
                  style={{
                    position: "absolute",
                    inset: 0,
                    borderRadius: "16px",
                    overflow: "hidden",
                  }}
                >
                  <span
                    style={{
                      position: "absolute",
                      inset: 0,
                      transformOrigin: "left center",
                      background:
                        "linear-gradient(135deg, #22d3ee 0%, #818cf8 50%, #f472b6 100%)",
                      animation: "portalButtonFill 0.45s ease-out forwards",
                    }}
                  />
                </span>
              )}

              <span
                style={{
                  position: "relative",
                  zIndex: 1,
                  display: "inline-flex",
                  alignItems: "center",
                  justifyContent: "center",
                  width: "100%",
                }}
              >
                {isLoading ? "Signing In..." : "Sign In"}
              </span>
            </button>
          </form>
        </div>
      </div>

      <style>
        {`
          @keyframes portalButtonFill {
            0% {
              transform: scaleX(0);
            }
            100% {
              transform: scaleX(1);
            }
          }
        `}
      </style>
    </div>
  );
}

const inputStyle = {
  width: "100%",
  padding: "15px 16px",
  borderRadius: "16px",
  border: "1px solid rgba(255,255,255,0.12)",
  background: "rgba(255,255,255,0.05)",
  color: "#ffffff",
  outline: "none",
  fontSize: "1rem",
  boxSizing: "border-box",
};

const buttonStyle = {
  marginTop: "4px",
  border: "none",
  borderRadius: "16px",
  padding: "15px 18px",
  fontWeight: 900,
  fontSize: "1rem",
  color: "#081120",
  background: "linear-gradient(135deg, #67e8f9 0%, #a78bfa 50%, #f472b6 100%)",
  boxShadow: "0 16px 34px rgba(103,232,249,0.20)",
};

const errorStyle = {
  width: "100%",
  boxSizing: "border-box",
  textAlign: "left",
  padding: "12px 14px",
  borderRadius: "14px",
  background: "rgba(239,68,68,0.14)",
  border: "1px solid rgba(248,113,113,0.35)",
  color: "#fecaca",
  fontSize: "0.92rem",
  fontWeight: 700,
};