import Link from "next/link";
import { PageSectionHeader } from "@/components/page-section-header";

const toolLinks = [
  { href: "/dashboard/posts", title: "Posts", desc: "Review or edit what you have shared on the community feed." },
  { href: "/dashboard/events", title: "Events", desc: "Schedule workshops and gatherings you host." },
  { href: "/dashboard/workshops", title: "Workshop Files", desc: "Upload and organize materials for your workshop cohorts." },
  { href: "/dashboard/repository", title: "Repository Files", desc: "Keep shared reference documents and images in one library." },
] as const;

export default function DashboardHomePage() {
  return (
    <div className="stack" style={{ gap: 20 }}>
      <section className="content-card stack" style={{ gap: 12 }}>
        <PageSectionHeader
          title="How this site is organized"
          description="Community is forums and events. Collaboration is shared projects, polls, and the exchange hub. Resources is the knowledge repository, workshop file uploads, and the farm directory. You is profile, posts, chat, and settings. This hub highlights shortcuts to the tools you use most; staff see an admin console when their role allows it."
        />
        <div className="app-bridges">
          <Link href="/platform/feed" className="app-bridge-card">
            <span className="app-bridge-kicker">Community</span>
            <span className="app-bridge-title">Open forums</span>
            <span className="app-bridge-desc">Read and join the community conversation in the forums.</span>
          </Link>
          <Link href="/dashboard/posts" className="app-bridge-card">
            <span className="app-bridge-kicker">Workspace</span>
            <span className="app-bridge-title">Manage posts &amp; files</span>
            <span className="app-bridge-desc">Jump to posts, events, workshop uploads, and repository files you maintain from the workspace.</span>
          </Link>
        </div>
      </section>

      <section className="content-card stack" style={{ gap: 14 }}>
        <h2 className="section-title">Quick links</h2>
        <div className="welcome-tiles">
          {toolLinks.map((t) => (
            <Link key={t.href} href={t.href} className="welcome-tile">
              <span className="welcome-tile-title">{t.title}</span>
              <span className="welcome-tile-desc">{t.desc}</span>
            </Link>
          ))}
        </div>
      </section>
    </div>
  );
}
