import { ProfileFollowListPage } from "@/components/profile-follow-list-page";

type PageProps = {
  params: Promise<{ userId: string }>;
};

export default async function PlatformUserFollowersPage({ params }: PageProps) {
  const { userId } = await params;
  return (
    <ProfileFollowListPage
      userId={userId}
      title="Followers"
      description="People who follow this member."
      emptyMessage="No followers yet."
      followColumn="follower_id"
      filterColumn="following_id"
    />
  );
}
