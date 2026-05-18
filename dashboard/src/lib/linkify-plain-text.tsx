import { Fragment, type ReactNode } from "react";

function trimUrlEnds(url: string): string {
  let s = url;
  while (s.length) {
    const last = s[s.length - 1];
    if (".,;:!?".includes(last)) {
      s = s.slice(0, -1);
      continue;
    }
    if (last === ")") {
      const opens = (s.match(/\(/g) ?? []).length;
      const closes = (s.match(/\)/g) ?? []).length;
      if (closes > opens) {
        s = s.slice(0, -1);
        continue;
      }
    }
    if (last === "]") {
      s = s.slice(0, -1);
      continue;
    }
    break;
  }
  return s;
}

export function linkifyPlainText(text: string, linkClassName = "inline-link"): ReactNode {
  if (!text) return null;

  const re = /\bhttps?:\/\/[^\s<]+/gi;
  const nodes: ReactNode[] = [];
  let last = 0;
  let m: RegExpExecArray | null;
  let anchorKey = 0;
  let fragKey = 0;

  while ((m = re.exec(text)) !== null) {
    if (m.index > last) {
      nodes.push(<Fragment key={`t${fragKey++}`}>{text.slice(last, m.index)}</Fragment>);
    }
    const raw = m[0];
    const href = trimUrlEnds(raw);
    const leftover = raw.slice(href.length);
    nodes.push(
      <a key={`a${anchorKey++}`} href={href} target="_blank" rel="noopener noreferrer" className={linkClassName}>
        {href}
      </a>
    );
    if (leftover) {
      nodes.push(<Fragment key={`t${fragKey++}`}>{leftover}</Fragment>);
    }
    last = m.index + raw.length;
  }

  if (last < text.length) {
    nodes.push(<Fragment key={`t${fragKey++}`}>{text.slice(last)}</Fragment>);
  }

  if (nodes.length === 0) {
    return text;
  }

  return <>{nodes}</>;
}
