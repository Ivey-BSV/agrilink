"use client";

type FeedPostActionBarProps = {
  liked: boolean;
  likeCount: number;
  commentCount: number;
  onLike: () => void;
  onComment: () => void;
  viewAllCommentsLabel?: boolean;
};

function HeartIcon({ filled }: { filled: boolean }) {
  if (filled) {
    return (
      <svg width="22" height="22" viewBox="0 0 24 24" aria-hidden>
        <path
          fill="currentColor"
          d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z"
        />
      </svg>
    );
  }
  return (
    <svg width="22" height="22" viewBox="0 0 24 24" aria-hidden>
      <path
        fill="none"
        stroke="currentColor"
        strokeWidth="1.8"
        d="M16.5 3c-1.74 0-3.41.81-4.5 2.09C10.91 3.81 9.24 3 7.5 3 4.42 3 2 5.42 2 8.5c0 3.78 3.4 6.86 8.55 11.54L12 21.35l1.45-1.32C18.6 15.36 22 12.28 22 8.5 22 5.42 19.58 3 16.5 3z"
      />
    </svg>
  );
}

function CommentIcon() {
  return (
    <svg width="22" height="22" viewBox="0 0 24 24" aria-hidden>
      <path
        fill="none"
        stroke="currentColor"
        strokeWidth="1.8"
        d="M21 11.5a8.38 8.38 0 0 1-.9 3.8 8.5 8.5 0 0 1-7.6 4.7 8.38 8.38 0 0 1-3.8-.9L3 21l1.9-5.7a8.38 8.38 0 0 1-.9-3.8 8.5 8.5 0 0 1 4.7-7.6 8.38 8.38 0 0 1 3.8-.9h.5a8.48 8.48 0 0 1 8 8v.5z"
      />
    </svg>
  );
}

export function FeedPostActionBar({
  liked,
  likeCount,
  commentCount,
  onLike,
  onComment,
  viewAllCommentsLabel = true,
}: FeedPostActionBarProps) {
  const commentLabel =
    commentCount === 1
      ? viewAllCommentsLabel
        ? "View 1 comment"
        : "1 comment"
      : viewAllCommentsLabel
        ? `View all ${commentCount} comments`
        : `${commentCount} comments`;

  return (
    <div className="feed-post-action-bar">
      <div className="feed-post-action-icons">
        <button
          type="button"
          className={`feed-post-icon-btn${liked ? " liked" : ""}`}
          onClick={onLike}
          aria-label={liked ? "Unlike post" : "Like post"}
          aria-pressed={liked}
        >
          <HeartIcon filled={liked} />
        </button>
        <button type="button" className="feed-post-icon-btn" onClick={onComment} aria-label="View comments">
          <CommentIcon />
        </button>
      </div>
      {likeCount > 0 || commentCount > 0 ? (
        <div className="feed-post-action-meta">
          {likeCount > 0 ? (
            <div className="feed-post-like-count">{likeCount === 1 ? "1 like" : `${likeCount} likes`}</div>
          ) : null}
          {commentCount > 0 ? (
            <button type="button" className="feed-post-comment-link" onClick={onComment}>
              {commentLabel}
            </button>
          ) : null}
        </div>
      ) : null}
    </div>
  );
}
