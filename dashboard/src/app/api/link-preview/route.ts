import { NextRequest, NextResponse } from "next/server";
import { fetchOpenGraphImageUrl } from "@/lib/link-preview";
import { parseSafeExternalUrl } from "@/lib/ssrf-safe-url";

export async function GET(request: NextRequest) {
  const url = request.nextUrl.searchParams.get("url");
  if (!url?.trim()) {
    return NextResponse.json({ error: "Missing url parameter" }, { status: 400 });
  }

  try {
    parseSafeExternalUrl(url.trim());
  } catch {
    return NextResponse.json({ error: "URL is not allowed" }, { status: 400 });
  }

  const imageUrl = await fetchOpenGraphImageUrl(url.trim());
  return NextResponse.json({ imageUrl });
}
