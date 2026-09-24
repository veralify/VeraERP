'use client';

import { useEffect, useState } from 'react';

/**
 * Renders a timestamp in the viewer's own time zone. Server components format with
 * the server's zone (UTC in production), so times rendered there were off by the
 * viewer's UTC offset. The server pass prints an explicit UTC label until hydration.
 */
export function LocalDateTime({ iso }: { iso: string }) {
  const [text, setText] = useState(() =>
    new Date(iso).toLocaleString('en-GB', { timeZone: 'UTC', timeZoneName: 'short' }),
  );

  useEffect(() => {
    setText(
      new Date(iso).toLocaleString(undefined, {
        dateStyle: 'medium',
        timeStyle: 'short',
      }),
    );
  }, [iso]);

  return <time dateTime={iso}>{text}</time>;
}
