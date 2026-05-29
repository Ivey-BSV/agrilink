import { ProfileFollowListPage } from "@/components/profile-follow-list-page";

type PageProps = {
  params: Promise<{ userId: string }>;
};

export default async function PlatformUserFollowingPage({ params }: PageProps) {
  const { userId } = await params;
  return (
    <ProfileFollowListPage
      userId={userId}
      title="Following"
      description="Members this person follows."
      emptyMessage="Not following anyone yet."
      followColumn="following_id"
      filterColumn="follower_id"
    />
  );
}
