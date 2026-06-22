"use client";

import Link from "next/link";
import { PostMediaPreview } from "@/components/post-media-preview";
import { FeedPostActionBar } from "@/components/feed-post-action-bar";
import { UserAvatar } from "@/components/user-avatar";
import { formatRelativeTime } from "@/lib/format";

export type FeedPostCardData = {
  id: string;
  user_id: string;
  title: string | null;
  content: string | null;
  location: string | null;
  created_at: string;
};

export type FeedPostCardProfile = {
  full_name: string | null;
  username: string | null;
  avatar_url: string | null;
};

type FeedPostCardProps = {
  post: FeedPostCardData;
  profile: FeedPostCardProfile | undefined;
  imageUrl: string | null;
  isVideo: boolean;
  tags: string[];
  heading: string | null;
  likeCount: number;
  commentCount: number;
  liked: boolean;
  authorProfileHref: string;
  authorLabel: string;
  canEditPost: boolean;
  onLike: () => void;
  onOpenPost: () => void;
  onComment: () => void;
  onEdit?: () => void;
  onDelete?: () => void;
};

export function FeedPostCard({
  post,
  profile,
  imageUrl,
  isVideo,
  tags,
  heading,
  likeCount,
  commentCount,
  liked,
  authorProfileHref,
  authorLabel,
  canEditPost,
  onLike,
  onOpenPost,
  onComment,
  onEdit,
  onDelete,
}: FeedPostCardProps) {
  const rawName = profile?.full_name?.trim();
  const uname = profile?.username?.trim();
  const displayName = rawName || (uname ? `@${uname}` : "Farmer");

  const metaParts = [formatRelativeTime(post.created_at)];
  if (post.location?.trim()) metaParts.push(post.location.trim());
  const metaLine = metaParts.join(" · ");

  return (
    <article className="feed-post feed-post--social">
      <div className="feed-post-content-wrap">
        <header className="feed-post-header feed-post-header--social">
          <Link href={authorProfileHref} className="feed-post-author-link" aria-label={`View ${authorLabel}'s profile`}>
            <UserAvatar url={profile?.avatar_url} name={authorLabel} size={36} />
          </Link>
          <div className="feed-post-header-main">
            <Link href={authorProfileHref} className="feed-post-name feed-post-author-link">
              {displayName}
            </Link>
            <div className="feed-post-meta-line">{metaLine}</div>
          </div>
          {canEditPost ? (
            <div className="feed-post-owner-actions">
              {onEdit ? (
                <button type="button" className="feed-post-owner-btn" onClick={onEdit}>
                  Edit
                </button>
              ) : null}
              {onDelete ? (
                <button type="button" className="feed-post-owner-btn feed-post-owner-btn--danger" onClick={onDelete}>
                  Delete
                </button>
              ) : null}
            </div>
          ) : null}
        </header>

        <button type="button" className="feed-post-tap-target" onClick={onOpenPost}>
          {heading ? <h2 className="feed-post-title feed-post-title--clamp">{heading}</h2> : null}
          {post.content?.trim() ? (
            <p className="feed-post-body feed-post-body--clamp feed-post-body--plain">{post.content.trim()}</p>
          ) : null}
          {tags.length > 0 ? (
            <p className="feed-post-tags-inline">{tags.map((t) => `#${t}`).join(" ")}</p>
          ) : null}
        </button>
      </div>

      {imageUrl ? (
        <div className="feed-post-media feed-post-media--landscape">
          <PostMediaPreview
            mediaUrl={imageUrl}
            triggerClassName="feed-post-media-trigger feed-post-media-trigger--landscape"
            imageClassName="feed-post-media-img feed-post-media-img--landscape"
            isVideo={isVideo}
            onOpen={onOpenPost}
          />
        </div>
      ) : null}

      <FeedPostActionBar
        liked={liked}
        likeCount={likeCount}
        commentCount={commentCount}
        onLike={onLike}
        onComment={onComment}
      />
    </article>
  );
}
