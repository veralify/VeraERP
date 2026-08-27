#!/usr/bin/env node
import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, '..');
const tokenPath = join(root, 'tokens', 'tokens.json');
const tokens = JSON.parse(readFileSync(tokenPath, 'utf8'));
const header = 'GENERATED from tokens.json — edit tokens.json';

const kebab = (s) =>
  String(s)
    .replace(/([a-z0-9])([A-Z])/g, '$1-$2')
    .replace(/\s+/g, '-')
    .toLowerCase();
const camel = (s) =>
  String(s)
    .replace(/[-\s]+([a-z0-9])/g, (_, c) => c.toUpperCase())
    .replace(/^[0-9]/, (d) => `_${d}`);
const px = (n) => `${n}px`;
const cleanHex = (hex) => hex.replace('#', '');
const hex6 = (hex) => cleanHex(hex).slice(0, 6);

function srgb(c) {
  c /= 255;
  return c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4;
}
function luminance(hex) {
  const clean = hex6(hex);
  const r = Number.parseInt(clean.slice(0, 2), 16);
  const g = Number.parseInt(clean.slice(2, 4), 16);
  const b = Number.parseInt(clean.slice(4, 6), 16);
  return 0.2126 * srgb(r) + 0.7152 * srgb(g) + 0.0722 * srgb(b);
}
function contrast(a, b) {
  const l1 = luminance(a);
  const l2 = luminance(b);
  return (Math.max(l1, l2) + 0.05) / (Math.min(l1, l2) + 0.05);
}
function checkContrast() {
  const pairs = [
    ['dark.fg/bg', tokens.color.semantic.dark.fg, tokens.color.semantic.dark.bg],
    ['dark.fg-muted/bg', tokens.color.semantic.dark['fg-muted'], tokens.color.semantic.dark.bg],
    ['dark.fg/surface', tokens.color.semantic.dark.fg, tokens.color.semantic.dark.surface],
    [
      'dark.on-primary/primary',
      tokens.color.semantic.dark['on-primary'],
      tokens.color.semantic.dark.primary,
    ],
    [
      'dark.on-secondary/secondary',
      tokens.color.semantic.dark['on-secondary'],
      tokens.color.semantic.dark.secondary,
    ],
    ['light.fg/bg', tokens.color.semantic.light.fg, tokens.color.semantic.light.bg],
    ['light.fg-muted/bg', tokens.color.semantic.light['fg-muted'], tokens.color.semantic.light.bg],
    ['light.fg/surface', tokens.color.semantic.light.fg, tokens.color.semantic.light.surface],
    [
      'light.on-primary/primary',
      tokens.color.semantic.light['on-primary'],
      tokens.color.semantic.light.primary,
    ],
    [
      'light.on-secondary/secondary',
      tokens.color.semantic.light['on-secondary'],
      tokens.color.semantic.light.secondary,
    ],
  ];
  for (const [name, fg, bg] of pairs) {
    const ratio = contrast(fg, bg);
    if (ratio < 4.5)
      console.warn(`Warning: ${name} contrast ${ratio.toFixed(2)} is below WCAG AA 4.5:1`);
  }
}

function cssThemeVars() {
  const lines = [];
  lines.push(`  --font-sans: ${tokens.typography.fontFamily.sans};`);
  lines.push(`  --font-mono: ${tokens.typography.fontFamily.mono};`);
  for (const [name] of Object.entries(tokens.color.semantic.dark))
    lines.push(`  --color-vera-${name}: var(--vera-color-${name});`);
  for (const domain of ['nutrition', 'progress', 'live']) {
    for (const [name] of Object.entries(tokens.color[domain].dark))
      lines.push(`  --color-vera-${kebab(name)}: var(--vera-color-${domain}-${kebab(name)});`);
  }
  for (const [name] of Object.entries(tokens.spacing))
    lines.push(`  --spacing-vera-${name}: var(--vera-space-${name});`);
  for (const [name] of Object.entries(tokens.radii))
    lines.push(`  --radius-vera-${kebab(name)}: var(--vera-radius-${kebab(name)});`);
  for (const [name] of Object.entries(tokens.breakpoints))
    lines.push(`  --breakpoint-${name}: ${px(tokens.breakpoints[name])};`);
  return lines.join('\n');
}

function writeCss() {
  const out = [];
  out.push(`/* ${header} */`);
  out.push(':root, [data-theme="dark"] {');
  for (const [ramp, stops] of Object.entries(tokens.color.ramp))
    for (const [stop, value] of Object.entries(stops))
      out.push(`  --vera-color-${ramp}-${stop}: ${value};`);
  for (const [name, value] of Object.entries(tokens.color.semantic.dark))
    out.push(`  --vera-color-${name}: ${value};`);
  for (const [name, value] of Object.entries(tokens.color.nutrition.dark))
    out.push(`  --vera-color-nutrition-${name}: ${value};`);
  for (const [name, value] of Object.entries(tokens.color.progress.dark))
    out.push(`  --vera-color-progress-${kebab(name)}: ${value};`);
  for (const [name, value] of Object.entries(tokens.color.live.dark))
    out.push(`  --vera-color-live-${kebab(name)}: ${value};`);
  for (const [name, value] of Object.entries(tokens.spacing))
    out.push(`  --vera-space-${name}: ${px(value)};`);
  for (const [name, value] of Object.entries(tokens.radii))
    out.push(`  --vera-radius-${kebab(name)}: ${px(value)};`);
  for (const [name, value] of Object.entries(tokens.borders))
    out.push(`  --vera-border-${kebab(name)}: ${value}px;`);
  for (const [name, value] of Object.entries(tokens.elevation.shadow))
    out.push(`  --vera-shadow-${kebab(name)}: ${value};`);
  for (const [name, value] of Object.entries(tokens.elevation.blur))
    out.push(`  --vera-blur-${kebab(name)}: ${px(value)};`);
  for (const [name, value] of Object.entries(tokens.motion.duration))
    out.push(`  --vera-duration-${kebab(name)}: ${value}ms;`);
  for (const [name, value] of Object.entries(tokens.motion.easing))
    out.push(`  --vera-ease-${kebab(name)}: ${value};`);
  for (const [name, value] of Object.entries(tokens.zIndex))
    out.push(`  --vera-z-${kebab(name)}: ${value};`);
  for (const [name, value] of Object.entries(tokens.typography.scale)) {
    out.push(`  --vera-type-${kebab(name)}-size: ${px(value.size)};`);
    out.push(`  --vera-type-${kebab(name)}-line: ${px(value.lineHeight)};`);
    out.push(`  --vera-type-${kebab(name)}-weight: ${value.weight};`);
    out.push(`  --vera-type-${kebab(name)}-tracking: ${value.tracking}px;`);
  }
  out.push(`  --vera-safe-ios-minimum-hit-target: ${px(tokens.safeArea.ios.minimumHitTarget)};`);
  out.push(
    `  --vera-safe-ios-bottom-nav-clearance: ${px(tokens.safeArea.ios.bottomNavClearance)};`,
  );
  out.push(`  --vera-safe-ios-edge-padding: ${px(tokens.safeArea.ios.edgePadding)};`);
  out.push('}');
  out.push('');
  out.push('[data-theme="light"] {');
  for (const [name, value] of Object.entries(tokens.color.semantic.light))
    out.push(`  --vera-color-${name}: ${value};`);
  for (const [name, value] of Object.entries(tokens.color.nutrition.light))
    out.push(`  --vera-color-nutrition-${name}: ${value};`);
  for (const [name, value] of Object.entries(tokens.color.progress.light))
    out.push(`  --vera-color-progress-${kebab(name)}: ${value};`);
  for (const [name, value] of Object.entries(tokens.color.live.light))
    out.push(`  --vera-color-live-${kebab(name)}: ${value};`);
  out.push('}');
  out.push('');
  out.push('@theme {');
  out.push(cssThemeVars());
  out.push('}');
  out.push('');
  out.push('/* Transitional aliases for existing Veralify web classes. */');
  out.push(':root, [data-theme="dark"] {');
  out.push('  --page-bg: var(--vera-color-bg);');
  out.push('  --text-main: var(--vera-color-fg);');
  out.push('  --text-muted: var(--vera-color-fg-muted);');
  out.push('  --surface: color-mix(in srgb, var(--vera-color-surface) 82%, transparent);');
  out.push('  --surface-hover: color-mix(in srgb, var(--vera-color-elevated) 90%, transparent);');
  out.push('  --surface-border: var(--vera-color-border);');
  out.push('  --surface-elevated: var(--vera-color-elevated);');
  out.push('  --glass-bg: var(--vera-color-glass);');
  out.push('  --glass-border: var(--vera-color-glass-border);');
  out.push('  --brand-primary: var(--vera-color-primary);');
  out.push('  --brand-primary-hover: var(--vera-color-primary-strong);');
  out.push('}');
  writeFileSync(join(root, 'tokens', 'tokens.css'), `${out.join('\n')}\n`);
}

function swiftColorLine(name, light, dark) {
  return `        public static let ${camel(name)} = Color(light: "${cleanHex(light)}", dark: "${cleanHex(dark)}")`;
}
function writeSwift() {
  const out = [];
  out.push(`// ${header}`);
  out.push('import SwiftUI');
  out.push('#if canImport(UIKit)');
  out.push('import UIKit');
  out.push('#endif');
  out.push('');
  out.push('public enum VeraTokens {');
  out.push('    public enum Colors {');
  for (const name of Object.keys(tokens.color.semantic.dark))
    out.push(
      swiftColorLine(name, tokens.color.semantic.light[name], tokens.color.semantic.dark[name]),
    );
  out.push('');
  out.push('        public enum Nutrition {');
  for (const name of Object.keys(tokens.color.nutrition.dark))
    out.push(
      `    ${swiftColorLine(name, tokens.color.nutrition.light[name], tokens.color.nutrition.dark[name])}`,
    );
  out.push('        }');
  out.push('');
  out.push('        public enum Progress {');
  for (const name of Object.keys(tokens.color.progress.dark))
    out.push(
      `    ${swiftColorLine(name, tokens.color.progress.light[name], tokens.color.progress.dark[name])}`,
    );
  out.push('        }');
  out.push('');
  out.push('        public enum Live {');
  for (const name of Object.keys(tokens.color.live.dark))
    out.push(
      `    ${swiftColorLine(name, tokens.color.live.light[name], tokens.color.live.dark[name])}`,
    );
  out.push('        }');
  out.push('');
  out.push('        public enum Ramp {');
  for (const [ramp, stops] of Object.entries(tokens.color.ramp)) {
    out.push(`            public enum ${camel(ramp).replace(/^./, (c) => c.toUpperCase())} {`);
    for (const [stop, value] of Object.entries(stops))
      out.push(`                    public static let _${stop} = Color(hex: "${cleanHex(value)}")`);
    out.push('            }');
  }
  out.push('        }');
  out.push('    }');
  out.push('');
  out.push('    public enum Type {');
  out.push(
    '        public struct FontToken { public let size: CGFloat; public let lineHeight: CGFloat; public let weight: Font.Weight; public let tracking: CGFloat }',
  );
  const weight = (w) =>
    w >= 800
      ? 'heavy'
      : w >= 750
        ? 'bold'
        : w >= 700
          ? 'bold'
          : w >= 650
            ? 'semibold'
            : w >= 500
              ? 'medium'
              : 'regular';
  for (const [name, v] of Object.entries(tokens.typography.scale))
    out.push(
      `        public static let ${camel(name)} = FontToken(size: ${v.size}, lineHeight: ${v.lineHeight}, weight: .${weight(v.weight)}, tracking: ${v.tracking})`,
    );
  out.push('        public static let sans = "Inter"');
  out.push('        public static let mono = "SF Mono"');
  out.push('    }');
  out.push('');
  out.push('    public enum Spacing {');
  for (const [name, value] of Object.entries(tokens.spacing))
    out.push(`        public static let _${name}: CGFloat = ${value}`);
  out.push('    }');
  out.push('');
  out.push('    public enum Radii {');
  for (const [name, value] of Object.entries(tokens.radii))
    out.push(`        public static let ${camel(name)}: CGFloat = ${value}`);
  out.push('    }');
  out.push('');
  out.push('    public enum Borders {');
  for (const [name, value] of Object.entries(tokens.borders))
    out.push(`        public static let ${camel(name)}: CGFloat = ${value}`);
  out.push('    }');
  out.push('');
  out.push('    public enum Motion {');
  out.push('        public enum Duration {');
  for (const [name, value] of Object.entries(tokens.motion.duration))
    out.push(`            public static let ${camel(name)} = Double(${value}) / 1000.0`);
  out.push('        }');
  out.push('    }');
  out.push('');
  out.push('    public enum ZIndex {');
  for (const [name, value] of Object.entries(tokens.zIndex))
    out.push(`        public static let ${camel(name)} = ${value}`);
  out.push('    }');
  out.push('');
  out.push('    public enum SafeArea {');
  out.push(
    `        public static let minimumHitTarget: CGFloat = ${tokens.safeArea.ios.minimumHitTarget}`,
  );
  out.push(
    `        public static let bottomNavClearance: CGFloat = ${tokens.safeArea.ios.bottomNavClearance}`,
  );
  out.push(`        public static let edgePadding: CGFloat = ${tokens.safeArea.ios.edgePadding}`);
  out.push('    }');
  out.push('}');
  out.push('');
  out.push('public extension Color {');
  out.push('    init(hex: String) {');
  out.push('        let cleaned = hex.trimmingCharacters(in: .alphanumerics.inverted)');
  out.push('        var value: UInt64 = 0');
  out.push('        Scanner(string: cleaned).scanHexInt64(&value)');
  out.push('        let r: Double');
  out.push('        let g: Double');
  out.push('        let b: Double');
  out.push('        let a: Double');
  out.push('        if cleaned.count > 6 {');
  out.push('            r = Double((value >> 24) & 0xFF) / 255.0');
  out.push('            g = Double((value >> 16) & 0xFF) / 255.0');
  out.push('            b = Double((value >> 8) & 0xFF) / 255.0');
  out.push('            a = Double(value & 0xFF) / 255.0');
  out.push('        } else {');
  out.push('            r = Double((value >> 16) & 0xFF) / 255.0');
  out.push('            g = Double((value >> 8) & 0xFF) / 255.0');
  out.push('            b = Double(value & 0xFF) / 255.0');
  out.push('            a = 1.0');
  out.push('        }');
  out.push('        self.init(red: r, green: g, blue: b, opacity: a)');
  out.push('    }');
  out.push('');
  out.push('    init(light: String, dark: String) {');
  out.push('#if canImport(UIKit)');
  out.push('        self.init(UIColor { traits in');
  out.push(
    '            traits.userInterfaceStyle == .dark ? UIColor(Color(hex: dark)) : UIColor(Color(hex: light))',
  );
  out.push('        })');
  out.push('#else');
  out.push('        self.init(hex: light)');
  out.push('#endif');
  out.push('    }');
  out.push('}');
  writeFileSync(join(root, 'tokens', 'Tokens.swift'), `${out.join('\n')}\n`);
}

checkContrast();
writeCss();
writeSwift();
