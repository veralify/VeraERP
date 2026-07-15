import { ImageResponse } from 'next/og';

export const runtime = 'edge';

const width = 1200;
const height = 630;

export async function GET() {
  const link = 'https://veralify.com';

  return new ImageResponse(
    <div
      style={{
        backgroundColor: 'white',
        display: 'flex',
        flexDirection: 'column',
        height: '100%',
        padding: '3rem',
        width: '100%',
      }}
    >
      <div
        style={{
          display: 'flex',
          height: '100%',
          width: '100%',
          backgroundColor: 'white',
          border: '6px solid black',
          borderRadius: '0.5rem',
          padding: '2rem',
          filter: 'drop-shadow(6px 6px 0 rgb(0 0 0 / 1))',
        }}
      >
        <div
          style={{
            display: 'flex',
            flexDirection: 'column',
            justifyContent: 'space-between',
            width: '100%',
          }}
        >
          <div style={{ display: 'flex', flexDirection: 'column', gap: '0.75rem' }}>
            <p style={{ fontSize: 48 }}>Veralify</p>
            <p style={{ fontSize: 38 }}>Ownership verification platform</p>
            <p style={{ fontSize: 38 }}>Coming soon</p>
          </div>
          <div
            style={{
              display: 'flex',
              justifyContent: 'space-between',
              alignItems: 'baseline',
            }}
          >
            <p style={{ fontSize: 32 }}>{link}</p>
          </div>
        </div>
      </div>
    </div>,
    { width, height },
  );
}
