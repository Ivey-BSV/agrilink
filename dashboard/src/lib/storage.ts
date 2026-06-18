export function extractStoragePathFromPublicUrl(
  publicUrl: string,
  bucketName: string
): string | null {
  const marker = `/storage/v1/object/public/${bucketName}/`;
  const idx = publicUrl.indexOf(marker);
  if (idx === -1) return null;
  const pathWithParams = publicUrl.slice(idx + marker.length);
  const [path] = pathWithParams.split("?");
  return path || null;
}