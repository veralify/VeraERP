import { Fragment } from 'react';

// Renders a translated string, converting **bold** segments into <strong> and
// \n into line breaks, so localized copy can keep its emphasis and layout.
export function renderRich(text: string) {
  const lines = text.split('\n');
  return lines.map((line, lineIndex) => {
    const segments = line.split(/(\*\*[^*]+\*\*)/g).map((part, partIndex) => {
      if (part.startsWith('**') && part.endsWith('**')) {
        // biome-ignore lint/suspicious/noArrayIndexKey: static, order-stable segments
        return <strong key={partIndex}>{part.slice(2, -2)}</strong>;
      }
      // biome-ignore lint/suspicious/noArrayIndexKey: static, order-stable segments
      return <Fragment key={partIndex}>{part}</Fragment>;
    });
    return (
      // biome-ignore lint/suspicious/noArrayIndexKey: static, order-stable lines
      <Fragment key={lineIndex}>
        {lineIndex > 0 ? <br /> : null}
        {segments}
      </Fragment>
    );
  });
}
