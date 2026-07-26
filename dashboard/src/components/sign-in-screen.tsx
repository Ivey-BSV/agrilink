"use client";

import Link from "next/link";
import { FormEvent, useEffect, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { supabase } from "@/lib/supabase";
import { SiteBrandMark } from "@/components/site-brand";
import { normalizeUsername } from "@/lib/username";
import {
  resetPasswordViaEdgeFunction,
  resolveEmailForPasswordSignIn,
} from "@/lib/web-auth";
import { safeRedirectPath } from "@/lib/safe-redirect-path";

type AuthMode = "signIn" | "register" | "forgotPassword";

export function SignInScreen() {
  const [mode, setMode] = useState<AuthMode>("signIn");
  const [signInIdentifier, setSignInIdentifier] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [forgotIdentifier, setForgotIdentifier] = useState("");
  const [forgotCode, setForgotCode] = useState("");
  const [forgotNewPassword, setForgotNewPassword] = useState("");
  const [forgotConfirmPassword, setForgotConfirmPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [fullName, setFullName] = useState("");
  const [username, setUsername] = useState("");
  const [acceptTerms, setAcceptTerms] = useState(false);
  const [acceptPrivacy, setAcceptPrivacy] = useState(false);
  const [showPassword, setShowPassword] = useState(false);
  const [showConfirmPassword, setShowConfirmPassword] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [info, setInfo] = useState<string | null>(null);
  const router = useRouter();
  const searchParams = useSearchParams();

  const nextPath = safeRedirectPath(searchParams.get("next"));

  useEffect(() => {
    setError(null);
    if (mode !== "forgotPassword") {
      setForgotIdentifier("");
      setForgotCode("");
      setForgotNewPassword("");
      setForgotConfirmPassword("");
    }
  }, [mode]);

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => {
      if (data.session?.user) {
        router.replace(nextPath);
      }
    });
  }, [router, nextPath]);

  const onSignIn = async (e: FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError(null);
    setInfo(null);

    let signInEmail: string;
    try {
      signInEmail = await resolveEmailForPasswordSignIn(supabase, signInIdentifier);
    } catch (resolveErr) {
      setError(resolveErr instanceof Error ? resolveErr.message : "Could not look up that account.");
      setLoading(false);
      return;
    }

    const { error: signInError } = await supabase.auth.signInWithPassword({
      email: signInEmail,
      password,
    });

    if (signInError) {
      setError(signInError.message);
      setLoading(false);
      return;
    }

    const {
      data: { session },
    } = await supabase.auth.getSession();
    if (!session?.user) {
      setError("Sign-in succeeded but no session was stored. Try again or clear site data for this origin.");
      setLoading(false);
      return;
    }

    router.replace(nextPath);
  };

  const onForgotPassword = async (e: FormEvent) => {
    e.preventDefault();
    setError(null);
    setInfo(null);

    if (forgotNewPassword.length < 6) {
      setError("New password must be at least 6 characters.");
      return;
    }
    if (forgotNewPassword !== forgotConfirmPassword) {
      setError("Passwords do not match.");
      return;
    }

    setLoading(true);
    try {
      await resetPasswordViaEdgeFunction(supabase, {
        usernameOrEmail: forgotIdentifier,
        code: forgotCode.trim(),
        newPassword: forgotNewPassword,
      });
      setInfo("Password updated. Sign in with your email or username and the new password.");
      setMode("signIn");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Reset failed.");
    } finally {
      setLoading(false);
    }
  };

  const checkUsernameAvailable = async (normalized: string): Promise<boolean | null> => {
    const { data, error: rpcError } = await supabase.rpc("is_username_available", {
      p_username: normalized,
    });
    if (rpcError) {
      return null;
    }
    return Boolean(data);
  };

  const onRegister = async (e: FormEvent) => {
    e.preventDefault();
    setError(null);
    setInfo(null);

    if (!fullName.trim()) {
      setError("Please enter your full name.");
      return;
    }
    if (password.length < 8) {
      setError("Password must be at least 8 characters.");
      return;
    }
    if (password !== confirmPassword) {
      setError("Passwords do not match.");
      return;
    }
    if (!acceptTerms || !acceptPrivacy) {
      setError("Please accept the Terms of Use and Privacy Policy to continue.");
      return;
    }

    const normalized = normalizeUsername(username);
    setLoading(true);

    const available = await checkUsernameAvailable(normalized);
    if (available === false) {
      setError("That username is already taken. Please choose another.");
      setLoading(false);
      return;
    }

    const origin = typeof window !== "undefined" ? window.location.origin : "";
    const { data, error: signUpError } = await supabase.auth.signUp({
      email: email.trim(),
      password,
      options: {
        emailRedirectTo: origin ? `${origin}/` : undefined,
        data: {
          username: normalized,
          full_name: fullName.trim(),
        },
      },
    });

    if (signUpError) {
      setError(signUpError.message);
      setLoading(false);
      return;
    }

    const user = data.user;
    if (!user) {
      setError("Registration could not be completed. Please try again.");
      setLoading(false);
      return;
    }

    const session = data.session;
    // Require a confirmed email before entering the app. When Supabase Auth
    // "Confirm email" is enabled, signUp returns no session until verified.
    if (!session || !user.email_confirmed_at) {
      if (session) {
        await supabase.auth.signOut();
      }
      setInfo(
        "Check your email for a confirmation link. After you confirm, return here and sign in with your email or username and password.",
      );
      setLoading(false);
      return;
    }

    const { error: upErr } = await supabase.from("user_profiles").upsert(
      {
        id: user.id,
        username: normalized,
        full_name: fullName.trim(),
        updated_at: new Date().toISOString(),
      },
      { onConflict: "id" },
    );
    if (upErr) {
      setError(upErr.message);
      setLoading(false);
      return;
    }
    router.replace(nextPath);
  };

  const heroTitle =
    mode === "signIn" ? "Welcome back" : mode === "register" ? "Create your account" : "Reset password";
  const heroBody =
    mode === "register" ? (
      <p>
        Create a farmer account for the Collective Action Program. Use a unique username (underscores instead of
        spaces). You can still use the mobile app with the same login.
      </p>
    ) : mode === "forgotPassword" ? (
      <p>
        Choose a new password using the program reset code (same as the mobile app). You will sign in again with your
        email or username.
      </p>
    ) : (
      <p>
        Sign in with the same email or username and password you use in the AgriLink mobile app. Web and app share one
        account, profile, and posts.
      </p>
    );

  return (
    <div className="signin-page">
      <div className="signin-hero">
        <div className="signin-hero-inner">
          <div className="signin-hero-brand">
            <SiteBrandMark size={52} />
          </div>
          <h2>{heroTitle}</h2>
          {heroBody}
        </div>
      </div>

      <div className="signin-panel">
        <div className="auth-card stack">
          {mode !== "forgotPassword" ? (
            <div className="signin-mode-tabs" role="tablist" aria-label="Sign in or register">
              <button
                type="button"
                role="tab"
                aria-selected={mode === "signIn"}
                className={`signin-mode-tab${mode === "signIn" ? " active" : ""}`}
                onClick={() => {
                  setInfo(null);
                  setMode("signIn");
                }}
              >
                Sign in
              </button>
              <button
                type="button"
                role="tab"
                aria-selected={mode === "register"}
                className={`signin-mode-tab${mode === "register" ? " active" : ""}`}
                onClick={() => {
                  setInfo(null);
                  setMode("register");
                }}
              >
                Create account
              </button>
            </div>
          ) : (
            <button
              type="button"
              className="signin-back-link"
              onClick={() => {
                setInfo(null);
                setMode("signIn");
              }}
            >
              ← Back to sign in
            </button>
          )}

          {mode === "signIn" ? (
            <>
              <div>
                <h1 className="title" style={{ fontSize: "1.5rem" }}>
                  Sign in
                </h1>
                <p className="subtle" style={{ marginTop: 8 }}>
                  Use your CAP / AgriLink email <strong>or</strong> username, and your password (same as the mobile app).
                </p>
              </div>

              <form onSubmit={onSignIn} className="stack">
                <div className="field">
                  <label htmlFor="signin-identifier">Email or username</label>
                  <input
                    id="signin-identifier"
                    type="text"
                    autoComplete="username"
                    required
                    value={signInIdentifier}
                    onChange={(e) => setSignInIdentifier(e.target.value)}
                    placeholder="you@example.com or jane_doe"
                  />
                </div>
                <div className="field">
                  <label htmlFor="signin-password">Password</label>
                  <div className="password-field">
                    <input
                      id="signin-password"
                      type={showPassword ? "text" : "password"}
                      autoComplete="current-password"
                      required
                      value={password}
                      onChange={(e) => setPassword(e.target.value)}
                    />
                    <button
                      type="button"
                      className="password-toggle"
                      onClick={() => setShowPassword((v) => !v)}
                      aria-label={showPassword ? "Hide password" : "Show password"}
                      aria-pressed={showPassword}
                    >
                      {showPassword ? "Hide" : "Show"}
                    </button>
                  </div>
                </div>

                {error ? <p className="error">{error}</p> : null}
                {info ? <p className="success">{info}</p> : null}

                <button className="btn btn-primary" disabled={loading} type="submit">
                  {loading ? "Signing in…" : "Sign in"}
                </button>
              </form>

              <button
                type="button"
                className="signin-forgot-link"
                onClick={() => {
                  setError(null);
                  setInfo(null);
                  setMode("forgotPassword");
                }}
              >
                Forgot password?
              </button>

              <p className="subtle" style={{ margin: 0 }}>
                New here? Switch to <strong>Create account</strong> above.
              </p>
            </>
          ) : mode === "register" ? (
            <>
              <div>
                <h1 className="title" style={{ fontSize: "1.5rem" }}>
                  Create account
                </h1>
                <p className="subtle" style={{ marginTop: 8 }}>
                  Full name, username, email, and password — same as the mobile app registration.
                </p>
              </div>

              <form onSubmit={onRegister} className="stack">
                <div className="field">
                  <label htmlFor="reg-full-name">Full name</label>
                  <input
                    id="reg-full-name"
                    type="text"
                    autoComplete="name"
                    required
                    value={fullName}
                    onChange={(e) => setFullName(e.target.value)}
                  />
                </div>
                <div className="field">
                  <label htmlFor="reg-username">Username</label>
                  <input
                    id="reg-username"
                    type="text"
                    autoComplete="username"
                    required
                    placeholder="e.g. jane_doe"
                    value={username}
                    onChange={(e) => setUsername(e.target.value)}
                  />
                  <span className="subtle" style={{ fontSize: "0.75rem" }}>
                    Lowercase, no spaces — use underscores.
                  </span>
                </div>
                <div className="field">
                  <label htmlFor="reg-email">Email</label>
                  <input
                    id="reg-email"
                    type="email"
                    autoComplete="email"
                    required
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                  />
                </div>
                <div className="field">
                  <label htmlFor="reg-password">Password</label>
                  <div className="password-field">
                    <input
                      id="reg-password"
                      type={showPassword ? "text" : "password"}
                      autoComplete="new-password"
                      required
                      minLength={8}
                      value={password}
                      onChange={(e) => setPassword(e.target.value)}
                    />
                    <button
                      type="button"
                      className="password-toggle"
                      onClick={() => setShowPassword((v) => !v)}
                      aria-label={showPassword ? "Hide password" : "Show password"}
                      aria-pressed={showPassword}
                    >
                      {showPassword ? "Hide" : "Show"}
                    </button>
                  </div>
                </div>
                <div className="field">
                  <label htmlFor="reg-confirm">Confirm password</label>
                  <div className="password-field">
                    <input
                      id="reg-confirm"
                      type={showConfirmPassword ? "text" : "password"}
                      autoComplete="new-password"
                      required
                      minLength={8}
                      value={confirmPassword}
                      onChange={(e) => setConfirmPassword(e.target.value)}
                    />
                    <button
                      type="button"
                      className="password-toggle"
                      onClick={() => setShowConfirmPassword((v) => !v)}
                      aria-label={showConfirmPassword ? "Hide confirm password" : "Show confirm password"}
                      aria-pressed={showConfirmPassword}
                    >
                      {showConfirmPassword ? "Hide" : "Show"}
                    </button>
                  </div>
                </div>

                <label className="signin-consent-row">
                  <input type="checkbox" checked={acceptTerms} onChange={(e) => setAcceptTerms(e.target.checked)} />
                  <span className="subtle">
                    I agree to the{" "}
                    <Link href="/legal/terms" target="_blank" rel="noopener noreferrer">
                      Terms of Use
                    </Link>
                    .
                  </span>
                </label>
                <label className="signin-consent-row">
                  <input type="checkbox" checked={acceptPrivacy} onChange={(e) => setAcceptPrivacy(e.target.checked)} />
                  <span className="subtle">
                    I agree to the{" "}
                    <Link href="/legal/privacy" target="_blank" rel="noopener noreferrer">
                      Privacy Policy
                    </Link>
                    .
                  </span>
                </label>

                {error ? <p className="error">{error}</p> : null}
                {info ? <p className="success">{info}</p> : null}

                <button className="btn btn-primary" disabled={loading} type="submit">
                  {loading ? "Creating account…" : "Create account"}
                </button>
              </form>

              <p className="subtle" style={{ margin: 0 }}>
                Already have an account? Switch to <strong>Sign in</strong> above.
              </p>
            </>
          ) : (
            <>
              <div>
                <h1 className="title" style={{ fontSize: "1.5rem" }}>
                  Reset password
                </h1>
                <p className="subtle" style={{ marginTop: 8 }}>
                  Enter your email or username, the program reset code, and a new password — same flow as the mobile
                  app.
                </p>
              </div>

              <form onSubmit={onForgotPassword} className="stack">
                <div className="field">
                  <label htmlFor="forgot-identifier">Email or username</label>
                  <input
                    id="forgot-identifier"
                    type="text"
                    autoComplete="username"
                    required
                    value={forgotIdentifier}
                    onChange={(e) => setForgotIdentifier(e.target.value)}
                    placeholder="you@example.com or jane_doe"
                  />
                </div>
                <div className="field">
                  <label htmlFor="forgot-code">Reset code</label>
                  <input
                    id="forgot-code"
                    type="text"
                    inputMode="numeric"
                    autoComplete="one-time-code"
                    required
                    value={forgotCode}
                    onChange={(e) => setForgotCode(e.target.value)}
                    placeholder="1234"
                  />
                </div>
                <div className="field">
                  <label htmlFor="forgot-new-password">New password</label>
                  <div className="password-field">
                    <input
                      id="forgot-new-password"
                      type={showPassword ? "text" : "password"}
                      autoComplete="new-password"
                      required
                      minLength={6}
                      value={forgotNewPassword}
                      onChange={(e) => setForgotNewPassword(e.target.value)}
                    />
                    <button
                      type="button"
                      className="password-toggle"
                      onClick={() => setShowPassword((v) => !v)}
                      aria-label={showPassword ? "Hide password" : "Show password"}
                      aria-pressed={showPassword}
                    >
                      {showPassword ? "Hide" : "Show"}
                    </button>
                  </div>
                </div>
                <div className="field">
                  <label htmlFor="forgot-confirm">Confirm new password</label>
                  <div className="password-field">
                    <input
                      id="forgot-confirm"
                      type={showConfirmPassword ? "text" : "password"}
                      autoComplete="new-password"
                      required
                      minLength={6}
                      value={forgotConfirmPassword}
                      onChange={(e) => setForgotConfirmPassword(e.target.value)}
                    />
                    <button
                      type="button"
                      className="password-toggle"
                      onClick={() => setShowConfirmPassword((v) => !v)}
                      aria-label={showConfirmPassword ? "Hide confirm password" : "Show confirm password"}
                      aria-pressed={showConfirmPassword}
                    >
                      {showConfirmPassword ? "Hide" : "Show"}
                    </button>
                  </div>
                </div>

                {error ? <p className="error">{error}</p> : null}

                <button className="btn btn-primary" disabled={loading} type="submit">
                  {loading ? "Updating…" : "Update password"}
                </button>
              </form>
            </>
          )}
        </div>
      </div>
    </div>
  );
}
