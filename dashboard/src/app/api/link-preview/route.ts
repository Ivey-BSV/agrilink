import { NextRequest, NextResponse } from "next/server";
import { fetchOpenGraphImageUrl } from "@/lib/link-preview";

export async function GET(request: NextRequest) {
  const url = request.nextUrl.searchParams.get("url");
  if (!url?.trim()) {
    return NextResponse.json({ error: "Missing url parameter" }, { status: 400 });
  }

  const imageUrl = await fetchOpenGraphImageUrl(url.trim());
  return NextResponse.json({ imageUrl });
}
