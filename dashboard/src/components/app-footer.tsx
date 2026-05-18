import Link from "next/link";
import type { User } from "@supabase/supabase-js";
import { SiteBrandMark } from "@/components/site-brand";

export function AppFooter({ user }: { user: User | null }) {
  return (
    <footer className="marketing-footer app-footer">
      <div className="marketing-footer-inner">
        <div className="marketing-footer-brand">
          <SiteBrandMark size={40} />
          <span className="marketing-footer-title">AgriLink</span>
        </div>
        <p className="marketing-footer-copy">© {new Date().getFullYear()} Collective Action Program (CAP). All rights reserved.</p>
        {!user ? (
          <div className="marketing-footer-links">
            <Link href="/" className="marketing-footer-a">
              Sign in
            </Link>
          </div>
        ) : null}
      </div>
    </footer>
  );
}
