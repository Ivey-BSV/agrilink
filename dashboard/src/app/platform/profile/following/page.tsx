import { ProfileFollowListPage } from "@/components/profile-follow-list-page";

export default function PlatformProfileFollowingPage() {
  return (
    <ProfileFollowListPage
      title="Following"
      description="People you follow."
      emptyMessage="You are not following anyone yet."
      followColumn="following_id"
      filterColumn="follower_id"
    />
  );
}
