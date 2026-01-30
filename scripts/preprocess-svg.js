const fs = require('fs');

function hexToRgb(hex) {
  const result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex);
  return result ? {
    r: parseInt(result[1], 16),
    g: parseInt(result[2], 16),
    b: parseInt(result[3], 16)
  } : null;
}

function rgbToHex(r, g, b) {
  return '#' + [r, g, b].map(x => {
    const hex = Math.round(Math.max(0, Math.min(255, x))).toString(16);
    return hex.length === 1 ? '0' + hex : hex;
  }).join('');
}

function colorMix(fg, bg, fgPercent) {
  const fgRgb = hexToRgb(fg);
  const bgRgb = hexToRgb(bg);
  if (!fgRgb || !bgRgb) return fg;
  
  const ratio = fgPercent / 100;
  return rgbToHex(
    fgRgb.r * ratio + bgRgb.r * (1 - ratio),
    fgRgb.g * ratio + bgRgb.g * (1 - ratio),
    fgRgb.b * ratio + bgRgb.b * (1 - ratio)
  );
}

function parseStyleVars(svgContent) {
  const vars = {};
  const styleMatch = svgContent.match(/style="([^"]*)"/);
  if (styleMatch) {
    const styleStr = styleMatch[1];
    const varMatches = styleStr.matchAll(/--([a-z]+):\s*([^;"\s]+)/gi);
    for (const m of varMatches) {
      vars['--' + m[1]] = m[2];
    }
  }
  return vars;
}

function preprocessSvg(svgContent) {
  const customVars = parseStyleVars(svgContent);
  
  const bg = customVars['--bg'] || '#FFFFFF';
  const fg = customVars['--fg'] || '#27272A';
  
  const arrowColor = customVars['--accent'] || colorMix(fg, bg, 70);
  
  const computed = {
    '--bg': bg,
    '--fg': fg,
    '--_text': fg,
    '--_text-sec': customVars['--muted'] || colorMix(fg, bg, 60),
    '--_text-muted': customVars['--muted'] || colorMix(fg, bg, 40),
    '--_text-faint': colorMix(fg, bg, 25),
    '--_line': arrowColor,
    '--_arrow': arrowColor,
    '--_node-fill': customVars['--surface'] || colorMix(fg, bg, 4),
    '--_node-stroke': customVars['--border'] || colorMix(fg, bg, 25),
    '--_group-fill': bg,
    '--_group-hdr': colorMix(fg, bg, 6),
    '--_inner-stroke': colorMix(fg, bg, 15),
    '--_key-badge': colorMix(fg, bg, 12),
  };

  let result = svgContent;
  
  const fontMatch = svgContent.match(/font-family:\s*'([^']+)'/);
  const fontFamily = fontMatch ? fontMatch[1] : 'Inter';
  
  result = result.replace(/<style>[\s\S]*?<\/style>/g, `<style>
  text { font-family: '${fontFamily}', 'SF Pro Display', system-ui, -apple-system, sans-serif; font-weight: 500; }
  .mono { font-family: 'JetBrains Mono', 'SF Mono', 'Fira Code', ui-monospace, monospace; }
</style>`);
  
  result = result.replace(/background:\s*var\(--bg\)/g, `background:${bg}`);
  
  for (const [varName, value] of Object.entries(computed)) {
    const pattern = new RegExp(`var\\(${varName.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}(?:,[^)]*)?\\)`, 'g');
    result = result.replace(pattern, value);
  }
  
  result = result.replace(/var\(--[^)]+\)/g, (match) => {
    return fg;
  });
  
  result = result.replace(/<polyline([^>]*?)stroke-width="0\.75"/g, '<polyline$1stroke-width="1.5"');
  
  result = result.replace(/markerWidth="8"/g, 'markerWidth="10"');
  result = result.replace(/markerHeight="4\.8"/g, 'markerHeight="6"');
  result = result.replace(/refX="8"/g, 'refX="10"');
  result = result.replace(/refY="2\.4"/g, 'refY="3"');
  result = result.replace(/points="0 0, 8 2\.4, 0 4\.8"/g, 'points="0 0, 10 3, 0 6"');
  result = result.replace(/points="8 0, 0 2\.4, 8 4\.8"/g, 'points="10 0, 0 3, 10 6"');
  
  return result;
}

if (process.argv.length < 3) {
  console.error('Usage: bun preprocess-svg.js <input.svg> [output.svg]');
  process.exit(1);
}

const inputPath = process.argv[2];
const outputPath = process.argv[3] || inputPath;

try {
  const svgContent = fs.readFileSync(inputPath, 'utf8');
  const processed = preprocessSvg(svgContent);
  fs.writeFileSync(outputPath, processed);
} catch (err) {
  console.error('Error:', err.message);
  process.exit(1);
}
