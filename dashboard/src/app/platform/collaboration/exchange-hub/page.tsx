"use client";

import { motion } from "framer-motion";
import { useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";
import { formatDate } from "@/lib/format";
import { parseImageUrls } from "@/lib/media-urls";
import { ContentThumbCell } from "@/components/content-thumb-cell";

type ListingRow = {
  id: string;
  title: string;
  price: string | null;
  description: string | null;
  location: string | null;
  created_at: string;
  image_urls: unknown;
};

export default function ExchangeHubPage() {
  const [items, setItems] = useState<ListingRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    const run = async () => {
      setLoading(true);
      const { data, error: e } = await supabase
        .from("marketplace_listings")
        .select("id, title, price, description, location, image_urls, created_at")
        .order("created_at", { ascending: false })
        .limit(80);
      if (cancelled) return;
      if (e) setError(e.message);
      else setItems((data as ListingRow[]) ?? []);
      setLoading(false);
    };
    void run();
    return () => {
      cancelled = true;
    };
  }, []);

  return (
    <motion.div className="content-card stack" style={{ gap: 16 }} initial={{ opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }}>
      <div>
        <h2 className="section-title">Exchange Hub</h2>
        <p className="subtle" style={{ marginTop: 8 }}>
          Browse equipment, services, and other listings members have shared. This view is for discovery only; publishing or editing a listing is done in your listing tools.
        </p>
      </div>
      {loading ? <p className="subtle">Loading listings…</p> : null}
      {error ? <p className="error">{error}</p> : null}
      {!loading && items.length === 0 ? <p className="empty">No listings yet.</p> : null}
      <div className="list">
        {items.map((item) => {
          const imageUrl = parseImageUrls(item.image_urls)[0] ?? null;
          return (
            <div key={item.id} className="list-item platform-post-card" style={{ display: "flex", gap: 12 }}>
              <ContentThumbCell imageUrl={imageUrl} />
              <div className="stack workshop-file-body" style={{ gap: 6, minWidth: 0 }}>
                <div className="workshop-line-title">{item.title}</div>
                <div className="workshop-line-meta">{item.price ?? "—"}</div>
                {item.description ? <div className="subtle" style={{ fontSize: "0.88rem" }}>{item.description}</div> : null}
                <div className="platform-post-meta-row">
                  {item.location ? <span className="pill">{item.location}</span> : null}
                  <span className="subtle">{formatDate(item.created_at)}</span>
                </div>
              </div>
            </div>
          );
        })}
      </div>
    </motion.div>
  );
}
