import React, { useEffect, useMemo, useRef, useState } from "react";

const LOGO_URL =
  "https://res.cloudinary.com/djtsuktwb/image/upload/v1769703507/ChatGPT_Image_Jan_29_2026_08_00_07_AM_1_3_gtqeo8.jpg";

const LOGIN_URL = "/v1/auth/login";

export default function Login() {
  const emailRef = useRef(null);
  const passwordRef = useRef(null);

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");

  const [showPassword, setShowPassword] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState("");

  const canSubmit = useMemo(() => {
    return email.trim().length > 0 && password.trim().length > 0 && !isLoading;
  }, [email, password, isLoading]);

  const debugLog = (label, payload = null) => {
    console.log(`🧪 [PORTAL LOGIN] ${label}`, payload || "");
  };

  const syncAutofilledFields = () => {
    const browserEmail = emailRef.current?.value || "";
    const browserPassword = passwordRef.current?.value || "";

    debugLog("syncAutofilledFields", {
      browserEmail,
      browserPasswordLength: browserPassword.length,
      stateEmail: email,
      statePasswordLength: password.length,
    });

    if (browserEmail && browserEmail !== email) {
      setEmail(browserEmail);
    }

    if (browserPassword && browserPassword !== password) {
      setPassword(browserPassword);
    }
  };

  useEffect(() => {
    debugLog("Login component mounted", {
      locationHref: window.location.href,
      origin: window.location.origin,
      pathname: window.location.pathname,
      loginUrl: LOGIN_URL,
    });

    syncAutofilledFields();

    const timeoutOne = setTimeout(syncAutofilledFields, 100);
    const timeoutTwo = setTimeout(syncAutofilledFields, 500);
    const timeoutThree = setTimeout(syncAutofilledFields, 1000);

    return () => {
      clearTimeout(timeoutOne);
      clearTimeout(timeoutTwo);
      clearTimeout(timeoutThree);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

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

    debugLog("SUBMIT EVENT FIRED");

    if (isLoading) {
      debugLog("Submit blocked because isLoading is true");
      return;
    }

    const browserEmail = emailRef.current?.value || email;
    const browserPassword = passwordRef.current?.value || password;

    const trimmedEmail = browserEmail.trim().toLowerCase();
    const trimmedPassword = browserPassword.trim();

    debugLog("Read form values", {
      browserEmail,
      trimmedEmail,
      browserPasswordLength: browserPassword.length,
      trimmedPasswordLength: trimmedPassword.length,
      stateEmail: email,
      statePasswordLength: password.length,
    });

    setEmail(browserEmail);
    setPassword(browserPassword);

    if (!trimmedEmail || !trimmedPassword) {
      debugLog("Submit stopped because email or password is missing", {
        hasEmail: Boolean(trimmedEmail),
        hasPassword: Boolean(trimmedPassword),
      });

      setError("Please enter your email and password.");
      return;
    }

    const requestBody = {
      user: {
        email: trimmedEmail,
        password: trimmedPassword,
      },
    };

    debugLog("About to send fetch", {
      loginUrl: LOGIN_URL,
      fullBrowserResolvedUrl: new URL(LOGIN_URL, window.location.origin).href,
      requestBodyPreview: {
        user: {
          email: requestBody.user.email,
          passwordLength: requestBody.user.password.length,
        },
      },
    });

    setError("");
    setIsLoading(true);

    const controller = new AbortController();
    const timeoutId = setTimeout(() => {
      debugLog("Fetch timeout hit after 10 seconds; aborting request");
      controller.abort();
    }, 10000);

    try {
      const response = await fetch(LOGIN_URL, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
        },
        body: JSON.stringify(requestBody),
        signal: controller.signal,
      });

      clearTimeout(timeoutId);

      debugLog("Fetch response received", {
        status: response.status,
        ok: response.ok,
        redirected: response.redirected,
        responseUrl: response.url,
        contentType: response.headers.get("content-type"),
      });

      const responseText = await response.text();

      debugLog("Raw response text", {
        responseText,
      });

      let data = null;

      try {
        data = responseText ? JSON.parse(responseText) : null;
      } catch (jsonError) {
        debugLog("Response was not valid JSON", {
          jsonErrorMessage: jsonError.message,
          responseText,
        });

        data = null;
      }

      debugLog("Parsed response data", data);

      if (!response.ok) {
        throw new Error(extractErrorMessage(data, response));
      }

      if (!data?.token) {
        throw new Error("Login succeeded, but no token was returned.");
      }

      debugLog("Login succeeded; saving token and redirecting", {
        userId: data.user?.id,
        email: data.user?.email,
        role: data.user?.role,
      });

      localStorage.setItem("portalToken", data.token);

      if (data.user) {
        localStorage.setItem("portalUser", JSON.stringify(data.user));
      }

      window.location.href = "/portal/dashboard";
    } catch (err) {
      clearTimeout(timeoutId);

      debugLog("Fetch/login crashed", {
        name: err.name,
        message: err.message,
        stack: err.stack,
      });

      if (err.name === "AbortError") {
        setError(
          "The login request timed out. The React app may not be reaching the Rails API."
        );
      } else if (err.message === "Failed to fetch") {
        setError(
          "The login request never reached the API. Check the React proxy and Rails server."
        );
      } else {
        setError(err.message || "Something went wrong while signing in.");
      }

      setIsLoading(false);
    }
  };

  const handleDebugDirectBrowserProbe = async () => {
    debugLog("Manual debug probe clicked");

    try {
      const response = await fetch(LOGIN_URL, {
        method: "OPTIONS",
      });

      debugLog("Manual OPTIONS probe response", {
        status: response.status,
        ok: response.ok,
        url: response.url,
      });
    } catch (err) {
      debugLog("Manual OPTIONS probe failed", {
        name: err.name,
        message: err.message,
      });

      setError(
        "Debug probe failed before reaching Rails. This points to proxy/dev-server setup."
      );
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
              ref={emailRef}
              type="email"
              placeholder="Email"
              style={inputStyle}
              autoComplete="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              onInput={(e) => setEmail(e.currentTarget.value)}
              onAnimationStart={syncAutofilledFields}
              onFocus={syncAutofilledFields}
              disabled={isLoading}
            />

            <div style={passwordFieldWrapperStyle}>
              <input
                ref={passwordRef}
                type={showPassword ? "text" : "password"}
                placeholder="Password"
                style={passwordInputStyle}
                autoComplete="current-password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                onInput={(e) => setPassword(e.currentTarget.value)}
                onAnimationStart={syncAutofilledFields}
                onFocus={syncAutofilledFields}
                disabled={isLoading}
              />

              <button
                type="button"
                aria-label={showPassword ? "Hide password" : "Show password"}
                title={showPassword ? "Hide password" : "Show password"}
                onClick={() => {
                  syncAutofilledFields();
                  setShowPassword((currentValue) => !currentValue);
                }}
                disabled={isLoading}
                style={{
                  ...eyeButtonStyle,
                  cursor: isLoading ? "wait" : "pointer",
                  opacity: isLoading ? 0.55 : 1,
                }}
              >
                {showPassword ? <EyeOffIcon /> : <EyeIcon />}
              </button>
            </div>

            {error ? <div style={errorStyle}>{error}</div> : null}

            <button
              type="submit"
              disabled={isLoading}
              style={{
                ...buttonStyle,
                opacity: isLoading ? 0.72 : 1,
                cursor: isLoading ? "wait" : "pointer",
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

            <button
              type="button"
              onClick={handleDebugDirectBrowserProbe}
              style={debugButtonStyle}
            >
              Debug API Probe
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

          @keyframes portalAutoFillStart {
            from {
              opacity: 1;
            }
            to {
              opacity: 1;
            }
          }

          input:-webkit-autofill {
            animation-name: portalAutoFillStart;
            animation-duration: 0.01s;
            animation-iteration-count: 1;
            -webkit-text-fill-color: #081120;
            box-shadow: 0 0 0 1000px #e8f0fe inset;
          }

          input:-webkit-autofill + button {
            color: #081120;
          }
        `}
      </style>
    </div>
  );
}

function EyeIcon() {
  return (
    <svg
      width="21"
      height="21"
      viewBox="0 0 24 24"
      fill="none"
      aria-hidden="true"
    >
      <path
        d="M2.25 12s3.5-6.75 9.75-6.75S21.75 12 21.75 12 18.25 18.75 12 18.75 2.25 12 2.25 12Z"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <path
        d="M12 15.25A3.25 3.25 0 1 0 12 8.75a3.25 3.25 0 0 0 0 6.5Z"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}

function EyeOffIcon() {
  return (
    <svg
      width="21"
      height="21"
      viewBox="0 0 24 24"
      fill="none"
      aria-hidden="true"
    >
      <path
        d="M3 3l18 18"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinecap="round"
      />
      <path
        d="M10.58 10.58a2.1 2.1 0 0 0 2.84 2.84"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinecap="round"
      />
      <path
        d="M9.1 5.6A10.7 10.7 0 0 1 12 5.25c6.25 0 9.75 6.75 9.75 6.75a18.1 18.1 0 0 1-3.02 3.92"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <path
        d="M14.12 6.03a3.28 3.28 0 0 1 3.85 3.85"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinecap="round"
      />
      <path
        d="M6.42 6.92C3.7 8.77 2.25 12 2.25 12S5.75 18.75 12 18.75c1.7 0 3.18-.5 4.43-1.19"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
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

const passwordFieldWrapperStyle = {
  width: "100%",
  position: "relative",
  display: "flex",
  alignItems: "center",
};

const passwordInputStyle = {
  ...inputStyle,
  paddingRight: "54px",
};

const eyeButtonStyle = {
  position: "absolute",
  right: "10px",
  top: "50%",
  transform: "translateY(-50%)",
  width: "38px",
  height: "38px",
  border: "none",
  borderRadius: "12px",
  background: "rgba(8,17,32,0.08)",
  color: "#081120",
  display: "inline-flex",
  alignItems: "center",
  justifyContent: "center",
  padding: 0,
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

const debugButtonStyle = {
  marginTop: "2px",
  border: "1px solid rgba(103,232,249,0.28)",
  borderRadius: "14px",
  padding: "11px 14px",
  fontWeight: 800,
  fontSize: "0.86rem",
  color: "#67e8f9",
  background: "rgba(103,232,249,0.08)",
  cursor: "pointer",
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