const ROUTE_TITLES: { prefix: string; title: string }[] = [
  { prefix: "/dashboard/admin/impersonation", title: "Impersonation" },
  { prefix: "/dashboard/admin/system", title: "System & export" },
  { prefix: "/dashboard/admin/staff", title: "Staff" },
  { prefix: "/dashboard/admin/audit", title: "Audit log" },
  { prefix: "/dashboard/admin/events", title: "All events" },
  // { prefix: "/dashboard/admin/documents", title: "Upload approvals" },
  { prefix: "/dashboard/admin/communications", title: "Broadcasts" },
  { prefix: "/dashboard/admin/farmers", title: "Farmers" },
  { prefix: "/dashboard/admin", title: "Admin console" },
  { prefix: "/dashboard/repository", title: "Repository" },
  { prefix: "/dashboard/workshops", title: "Workshops" },
  { prefix: "/dashboard/events", title: "Events" },
  { prefix: "/dashboard/listings", title: "Listings" },
  { prefix: "/dashboard/posts", title: "Posts" },
  { prefix: "/dashboard", title: "Dashboard" },
];

export function dashboardPageTitle(pathname: string | null): string {
  if (!pathname || !pathname.startsWith("/dashboard")) {
    return "Dashboard";
  }
  const sorted = [...ROUTE_TITLES].sort((a, b) => b.prefix.length - a.prefix.length);
  for (const { prefix, title } of sorted) {
    if (pathname === prefix || pathname.startsWith(prefix + "/")) {
      return title;
    }
  }
  return "Dashboard";
}
