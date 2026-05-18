export function SiteBrandMark({ size = 40 }: { size?: number }) {
  const s = { width: size, height: size };
  return (
    <span className="site-brand-mark" style={s} aria-hidden>
      <img
        src="/app-icon.png"
        alt=""
        width={size}
        height={size}
        className="site-brand-mark-img"
        draggable={false}
      />
    </span>
  );
}
