import { PostDetailView } from "@/components/post-detail-view";

type PageProps = {
  params: Promise<{ postId: string }>;
};

export default async function PlatformPostDetailPage({ params }: PageProps) {
  const { postId } = await params;
  return <PostDetailView postId={postId} />;
}
