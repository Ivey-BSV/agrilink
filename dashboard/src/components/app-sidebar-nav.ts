export type SidebarNavItem = {
  href: string;
  label: string;
  disabled?: boolean;
  soonLabel?: string;
};

export const communityNavItems: readonly SidebarNavItem[] = [
  { href: "/platform/feed", label: "Forums" },
  { href: "/dashboard/events", label: "Events" },
];

export const collaborationNavItems: readonly SidebarNavItem[] = [
  { href: "/platform/collaboration/projects", label: "Projects" },
  { href: "/platform/collaboration/polls", label: "Polls" },
  { href: "/platform/collaboration/exchange-hub", label: "Exchange Hub" },
];

export const resourcesNavItems: readonly SidebarNavItem[] = [
  { href: "/dashboard/repository", label: "Repository" },
  { href: "/dashboard/workshops", label: "Workshops" },
  { href: "/platform/directory", label: "Farm Directory" },
];

export const accountNavItems: readonly SidebarNavItem[] = [
  { href: "/platform/profile", label: "My Profile" },
  { href: "/dashboard/posts", label: "My Posts" },
  { href: "/dashboard/listings", label: "My Listings" },
  { href: "/platform/settings", label: "Settings" },
];

export const allMainNavItems: readonly SidebarNavItem[] = [
  ...communityNavItems,
  ...collaborationNavItems,
  ...resourcesNavItems,
  ...accountNavItems,
];

export function linkActive(pathname: string | null, href: string, options?: { disabled?: boolean }) {
  if (options?.disabled) return false;
  if (href === "/dashboard") return pathname === "/dashboard";
  return pathname === href || pathname?.startsWith(href + "/");
}
