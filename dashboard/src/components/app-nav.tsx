"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useMemo, useState } from "react";
import type { User } from "@supabase/supabase-js";
import { SiteBrandMark } from "@/components/site-brand";
import { UserAvatar } from "@/components/user-avatar";
import { useStaffAccess } from "@/components/staff-access-context";
import { useStaffMemberPreview } from "@/hooks/use-staff-member-preview";

function communitySectionActive(pathname: string | null) {
  if (!pathname) return false;
  return pathname.startsWith("/platform/feed") || pathname.startsWith("/dashboard/events");
}

function collaborationSectionActive(pathname: string | null) {
  if (!pathname) return false;
  return (
    pathname.startsWith("/platform/collaboration/projects") ||
    pathname.startsWith("/platform/collaboration/polls") ||
    pathname.startsWith("/platform/collaboration/exchange-hub")
  );
}

function resourcesSectionActive(pathname: string | null) {
  if (!pathname) return false;
  return (
    pathname.startsWith("/dashboard/repository") ||
    pathname.startsWith("/dashboard/workshops") ||
    pathname.startsWith("/platform/directory")
  );
}

function youSectionActive(pathname: string | null) {
  if (!pathname) return false;
  return (
    pathname.startsWith("/platform/profile") ||
    pathname.startsWith("/platform/settings") ||
    pathname.startsWith("/dashboard/posts") ||
    pathname.startsWith("/dashboard/listings")
  );
}

function chatNavActive(pathname: string | null) {
  if (!pathname) return false;
  return pathname === "/platform/chat" || pathname.startsWith("/platform/chat/");
}

function dashboardSectionActive(pathname: string | null, memberPreview: boolean) {
  if (!pathname) return false;
  if (memberPreview) {
    return pathname === "/dashboard";
  }
  if (pathname === "/dashboard") return true;
  return pathname.startsWith("/dashboard/admin");
}

export function AppNav({ user }: { user: User | null }) {
  const pathname = usePathname();
  const [open, setOpen] = useState(false);
  const { staffAccess, ready } = useStaffAccess();
  const { active: memberPreview } = useStaffMemberPreview();

  const showStaffTopNav = ready && staffAccess != null && !memberPreview;

  const dashboardHref = useMemo(() => {
    if (!user) return "/dashboard";
    if (!ready) return "/dashboard";
    return showStaffTopNav ? "/dashboard/admin" : "/dashboard";
  }, [user, ready, showStaffTopNav]);

  const dashboardLinkLabel = showStaffTopNav ? "Staff" : "Dashboard";

  const brandHref = user ? "/platform/feed" : "/";

  return (
    <header className="marketing-nav app-nav">
      <div className="marketing-nav-inner">
        <Link href={brandHref} className="marketing-brand" onClick={() => setOpen(false)}>
          <SiteBrandMark size={48} />
          <span className="marketing-brand-text">AgriLink</span>
        </Link>

        {user ? (
          <nav className="marketing-nav-links" aria-label="App">
            <Link
              href="/platform/feed"
              className={`marketing-nav-link${communitySectionActive(pathname) ? " active" : ""}`}
            >
              Community
            </Link>
            <Link
              href="/platform/collaboration/projects"
              className={`marketing-nav-link${collaborationSectionActive(pathname) ? " active" : ""}`}
            >
              Collaboration
            </Link>
            <Link
              href="/dashboard/repository"
              className={`marketing-nav-link${resourcesSectionActive(pathname) ? " active" : ""}`}
            >
              Resources
            </Link>
            <Link
              href="/platform/profile"
              className={`marketing-nav-link${youSectionActive(pathname) ? " active" : ""}`}
            >
              You
            </Link>
            <Link
              href={dashboardHref}
              className={`marketing-nav-link${dashboardSectionActive(pathname, memberPreview) ? " active" : ""}`}
            >
              {dashboardLinkLabel}
            </Link>
          </nav>
        ) : (
          <div className="marketing-nav-guest-spacer" aria-hidden="true" />
        )}

        <div className="marketing-nav-cta">
          {user ? (
            <>
              <Link
                href="/platform/chat"
                className={`marketing-nav-bell${chatNavActive(pathname) ? " active" : ""}`}
                aria-label="Messages"
                onClick={() => setOpen(false)}
              >
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  width={22}
                  height={22}
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth={2}
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  aria-hidden
                >
                  <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z" />
                </svg>
              </Link>
              <Link
                href="/platform/notifications"
                className={`marketing-nav-bell${pathname === "/platform/notifications" || pathname?.startsWith("/platform/notifications/") ? " active" : ""}`}
                aria-label="Notifications"
                onClick={() => setOpen(false)}
              >
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  width={22}
                  height={22}
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth={2}
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  aria-hidden
                >
                  <path d="M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9" />
                  <path d="M10.3 21a1.94 1.94 0 0 0 3.4 0" />
                </svg>
              </Link>
              <Link
                href="/platform/profile"
                className="marketing-nav-avatar-link"
                aria-label="My profile"
                onClick={() => setOpen(false)}
              >
                <UserAvatar email={user.email} size={36} />
              </Link>
            </>
          ) : (
            <Link href="/?next=/platform/feed" className="btn btn-primary marketing-nav-btn-main">
              Sign in
            </Link>
          )}
          {user ? (
            <button
              type="button"
              className="marketing-nav-burger"
              aria-expanded={open}
              aria-controls="app-mobile-menu"
              aria-label={open ? "Close menu" : "Open menu"}
              onClick={() => setOpen((v) => !v)}
            >
              <span className="marketing-burger-line" />
              <span className="marketing-burger-line" />
              <span className="marketing-burger-line" />
            </button>
          ) : null}
        </div>
      </div>

      {user ? (
        <div id="app-mobile-menu" className={`marketing-mobile-panel${open ? " open" : ""}`} aria-hidden={!open}>
          <Link
            href="/platform/feed"
            className={`marketing-mobile-link${communitySectionActive(pathname) ? " active" : ""}`}
            onClick={() => setOpen(false)}
          >
            Community
          </Link>
          <Link
            href="/platform/collaboration/projects"
            className={`marketing-mobile-link${collaborationSectionActive(pathname) ? " active" : ""}`}
            onClick={() => setOpen(false)}
          >
            Collaboration
          </Link>
          <Link
            href="/dashboard/repository"
            className={`marketing-mobile-link${resourcesSectionActive(pathname) ? " active" : ""}`}
            onClick={() => setOpen(false)}
          >
            Resources
          </Link>
          <Link
            href="/platform/profile"
            className={`marketing-mobile-link${youSectionActive(pathname) ? " active" : ""}`}
            onClick={() => setOpen(false)}
          >
            You
          </Link>
          <Link
            href={dashboardHref}
            className={`marketing-mobile-link${dashboardSectionActive(pathname, memberPreview) ? " active" : ""}`}
            onClick={() => setOpen(false)}
          >
            {dashboardLinkLabel}
          </Link>
        </div>
      ) : null}
    </header>
  );
}
