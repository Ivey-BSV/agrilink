"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  communityNavItems,
  collaborationNavItems,
  resourcesNavItems,
  accountNavItems,
  allMainNavItems,
  linkActive,
  type SidebarNavItem,
} from "@/components/app-sidebar-nav";
import { useStaffAccess } from "@/components/staff-access-context";
import { useStaffMemberPreview } from "@/hooks/use-staff-member-preview";

function NavBlock({
  label,
  ariaLabel,
  items,
  pathname,
}: {
  label: string;
  ariaLabel: string;
  items: readonly SidebarNavItem[];
  pathname: string | null;
}) {
  return (
    <>
      <div className="platform-sidebar-label">{label}</div>
      <nav className="platform-nav" aria-label={ariaLabel}>
        {items.map((item) =>
          item.disabled ? (
            <span
              key={item.href}
              className="platform-nav-item platform-nav-item--disabled"
              aria-disabled="true"
              aria-label={`${item.label} (${item.soonLabel ?? "Unavailable"})`}
            >
              <span>{item.label}</span>
              {item.soonLabel ? <span className="platform-nav-soon">{item.soonLabel}</span> : null}
            </span>
          ) : (
            <Link
              key={item.href}
              href={item.href}
              className={`platform-nav-item${linkActive(pathname, item.href) ? " active" : ""}`}
            >
              {item.label}
            </Link>
          ),
        )}
      </nav>
    </>
  );
}

export function AppSidebar() {
  const pathname = usePathname();
  const { staffAccess, ready } = useStaffAccess();
  const { active: memberPreview } = useStaffMemberPreview();
  const isStaff = staffAccess != null;
  const showStaffNav = isStaff && !memberPreview;

  return (
    <aside className="platform-sidebar app-shell-sidebar app-sidebar--desktop-only" aria-label="App sections">
      <NavBlock label="Community" ariaLabel="Community" items={communityNavItems} pathname={pathname} />
      <NavBlock label="Collaboration" ariaLabel="Collaboration" items={collaborationNavItems} pathname={pathname} />
      <NavBlock label="Resources" ariaLabel="Resources" items={resourcesNavItems} pathname={pathname} />
      <NavBlock label="You" ariaLabel="Account" items={accountNavItems} pathname={pathname} />

      <div className="platform-sidebar-label">{showStaffNav ? "Staff" : "Workspace"}</div>
      {!ready ? (
        <p className="app-shell-sidebar-muted" aria-busy="true">
          Checking staff access…
        </p>
      ) : showStaffNav ? (
        <nav className="platform-nav" aria-label="Staff">
          <Link
            href="/dashboard/admin"
            className={`platform-nav-item platform-nav-item--staff${linkActive(pathname, "/dashboard/admin") ? " active" : ""}`}
          >
            Admin console
          </Link>
        </nav>
      ) : (
        <nav className="platform-nav" aria-label="Workspace">
          <Link
            href="/dashboard"
            className={`platform-nav-item${linkActive(pathname, "/dashboard") ? " active" : ""}`}
          >
            Dashboard
          </Link>
        </nav>
      )}
    </aside>
  );
}

export function AppSidebarMobileNav() {
  const pathname = usePathname();
  const { staffAccess, ready } = useStaffAccess();
  const { active: memberPreview } = useStaffMemberPreview();
  const isStaff = ready && staffAccess != null;
  const showStaffNav = isStaff && !memberPreview;

  return (
    <nav className="platform-mobile-nav app-sidebar-mobile-strip" aria-label="Section navigation">
      {allMainNavItems.map((item) =>
        item.disabled ? (
          <span
            key={item.href}
            className="platform-mobile-pill platform-mobile-pill--disabled"
            aria-disabled="true"
            aria-label={`${item.label} (${item.soonLabel ?? "Unavailable"})`}
          >
            <span className="platform-mobile-pill-text">{item.label}</span>
            {item.soonLabel ? <span className="platform-mobile-pill-soon">{item.soonLabel}</span> : null}
          </span>
        ) : (
          <Link
            key={item.href}
            href={item.href}
            className={`platform-mobile-pill${linkActive(pathname, item.href) ? " active" : ""}`}
          >
            {item.label}
          </Link>
        ),
      )}
      {showStaffNav ? (
        <Link
          href="/dashboard/admin"
          className={`platform-mobile-pill platform-mobile-pill--staff${linkActive(pathname, "/dashboard/admin") ? " active" : ""}`}
        >
          Admin
        </Link>
      ) : (
        <Link
          href="/dashboard"
          className={`platform-mobile-pill${linkActive(pathname, "/dashboard") ? " active" : ""}`}
        >
          Dashboard
        </Link>
      )}
    </nav>
  );
}
