'use client';

import { useEffect, useState } from 'react';

/** Hidden input carrying the browser's IANA time zone so the server can interpret `datetime-local` values. */
export function TimeZoneField({ name = 'timeZone' }: { name?: string }) {
  const [timeZone, setTimeZone] = useState('UTC');

  useEffect(() => {
    setTimeZone(Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC');
  }, []);

  return <input type="hidden" name={name} value={timeZone} />;
}
