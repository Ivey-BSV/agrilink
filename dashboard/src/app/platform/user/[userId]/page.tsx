import { PlatformUserProfileView } from "@/components/platform-user-profile-view";

type PageProps = {
  params: Promise<{ userId: string }>;
};

export default async function PlatformUserProfilePage({ params }: PageProps) {
  const { userId } = await params;
  return <PlatformUserProfileView userId={userId} />;
}
