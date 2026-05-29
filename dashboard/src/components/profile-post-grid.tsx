"use client";

import Link from "next/link";
import { parseImageUrls } from "@/lib/media-urls";
import { PostMediaPreview } from "@/components/post-media-preview";

export type ProfilePostGridItem = {
  id: string;
  title?: string | null;
  image_urls: unknown;
};

type ProfilePostGridProps = {
  posts: ProfilePostGridItem[];
};

export function ProfilePostGrid({ posts }: ProfilePostGridProps) {
  return (
    <div className="profile-post-grid">
      {posts.map((post) => {
        const imageUrl = parseImageUrls(post.image_urls)[0] ?? null;
        const label = post.title?.trim() || "View post";
        return (
          <Link
            key={post.id}
            href={`/platform/post/${post.id}`}
            className="profile-post-grid-cell"
            title={label}
            aria-label={label}
          >
            {imageUrl ? (
              <PostMediaPreview mediaUrl={imageUrl} compact imageClassName="profile-post-grid-img" />
            ) : (
              <div className="profile-post-grid-placeholder profile-post-grid-text-only">
                <span className="profile-post-grid-glyph" aria-hidden>
                  📝
                </span>
              </div>
            )}
          </Link>
        );
      })}
    </div>
  );
}
