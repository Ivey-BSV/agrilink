"use client";

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import { FilePreviewModal } from "@/components/file-preview-modal";
import {
  buildMarqueeSequence,
  loadWorkshopBannerImages,
  type WorkshopBannerImage,
} from "@/lib/workshop-banner-images";

type WorkshopMarqueeBannerProps = {
  className?: string;
  /** Link label shown on the right (optional). */
  linkLabel?: string;
  linkHref?: string;
};

function MarqueeTile({
  image,
  onSelect,
}: {
  image: WorkshopBannerImage;
  onSelect: (image: WorkshopBannerImage) => void;
}) {
  const label = image.title ?? "Workshop photo";

  return (
    <button
      type="button"
      className="workshop-marquee-item"
      aria-label={`Preview ${label}`}
      onClick={() => onSelect(image)}
    >
      <img src={image.url} alt="" loading="lazy" decoding="async" draggable={false} />
    </button>
  );
}

export function WorkshopMarqueeBanner({
  className,
  linkLabel = "Workshops",
  linkHref = "/dashboard/workshops",
}: WorkshopMarqueeBannerProps) {
  const [images, setImages] = useState<WorkshopBannerImage[]>([]);
  const [preview, setPreview] = useState<WorkshopBannerImage | null>(null);

  useEffect(() => {
    let cancelled = false;

    void loadWorkshopBannerImages().then(({ images: loaded }) => {
      if (!cancelled) setImages(loaded);
    });

    return () => {
      cancelled = true;
    };
  }, []);

  const sequence = useMemo(() => buildMarqueeSequence(images), [images]);

  if (sequence.length === 0) return null;

  return (
    <>
      <section
        className={`workshop-marquee-banner${className ? ` ${className}` : ""}`}
        aria-label="Workshop photo highlights"
      >
        <div className="workshop-marquee-banner-head">
          <p className="workshop-marquee-banner-kicker">From our workshops</p>
          {linkHref ? (
            <Link href={linkHref} className="workshop-marquee-banner-link">
              {linkLabel}
            </Link>
          ) : null}
        </div>

        <div className="workshop-marquee-viewport">
          <div className="workshop-marquee-track">
            {sequence.map((image, index) => (
              <MarqueeTile key={`${image.id}-${index}`} image={image} onSelect={setPreview} />
            ))}
          </div>
        </div>
      </section>

      <FilePreviewModal
        open={preview != null}
        onClose={() => setPreview(null)}
        fileUrl={preview?.fullUrl ?? preview?.url ?? ""}
        fileName={preview?.title ?? "Workshop photo"}
        subtitle={preview?.folderName ? `From ${preview.folderName}` : null}
        hideFooter
      />
    </>
  );
}
