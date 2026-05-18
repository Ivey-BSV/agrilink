import { ProfileFollowListPage } from "@/components/profile-follow-list-page";

export default function PlatformProfileFollowersPage() {
  return (
    <ProfileFollowListPage
      title="Followers"
      description="People who follow you."
      emptyMessage="No followers yet."
      followColumn="follower_id"
      filterColumn="following_id"
    />
  );
}
