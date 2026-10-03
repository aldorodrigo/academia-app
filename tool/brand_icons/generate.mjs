// Genera los íconos, el favicon y las imágenes de la pantalla de inicio de
// Android, iOS y la web a partir de los SVG maestros de assets/brand/.
//
//   cd tool/brand_icons && npm install && node generate.mjs
import { readFileSync, writeFileSync, mkdirSync, copyFileSync, readdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { Resvg } from '@resvg/resvg-js';
import { PNG } from 'pngjs';

const root = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const brand = (name) => readFileSync(join(root, 'assets/brand', name), 'utf8');

const verde = '#167A3A';

// La cara de Tuku tal como va en la capa de frente del ícono adaptable.
const face = brand('tuku-icono-frente.svg').match(/<g transform[\s\S]*<\/g>/)[0];

const svgs = {
  icono: brand('tuku-icono.svg'),
  tienda: brand('tuku-icono-tienda.svg'),
  frente: brand('tuku-icono-frente.svg'),
  favicon: brand('tuku-favicon.svg'),
  logo: brand('tuku-logo.svg'),
  logoBlanco: brand('tuku-logo-blanco.svg'),
  // Ícono "maskable" de la web: fondo verde a sangre y la cara en la zona segura.
  maskable: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024"><rect width="1024" height="1024" fill="${verde}"/>${face}</svg>`,
  // Pantalla de inicio: el ícono adaptable recortado en círculo, como lo
  // muestra Android 12 (el círculo visible es el 66 % central del lienzo).
  splash: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="171 171 682 682"><circle cx="512" cy="512" r="341" fill="${verde}"/>${face}</svg>`,
  // Ícono chico de las notificaciones de Android: silueta blanca de la cara
  // (Android solo usa el canal alfa), con los ojos y la sonrisa calados.
  notificacion: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="-1 -1.5 66 66">
    <defs><mask id="cara"><rect x="-1" y="-1.5" width="66" height="66" fill="#fff"/>
      <circle cx="23" cy="35" r="8.5" fill="#000"/><circle cx="41" cy="35" r="8.5" fill="#000"/>
      <circle cx="25" cy="33.5" r="4.6" fill="#fff"/><circle cx="43" cy="33.5" r="4.6" fill="#fff"/>
      <path d="M26 46 Q32 51 38 46" fill="none" stroke="#000" stroke-width="3" stroke-linecap="round"/></mask></defs>
    <path d="M24 20 C22 13 18 9 13 8" fill="none" stroke="#fff" stroke-width="3.6" stroke-linecap="round"/>
    <path d="M40 20 C42 13 46 9 51 8" fill="none" stroke="#fff" stroke-width="3.6" stroke-linecap="round"/>
    <circle cx="12.5" cy="8" r="4.2" fill="#fff"/><circle cx="51.5" cy="8" r="4.2" fill="#fff"/>
    <ellipse cx="32" cy="38" rx="25" ry="21" fill="#fff" mask="url(#cara)"/></svg>`,
};

function render(svg, width) {
  return new Resvg(svg, { fitTo: { mode: 'width', value: width } }).render().asPng();
}

// App Store rechaza íconos con canal alfa: se aplanan sobre verde.
function opaque(png) {
  const src = PNG.sync.read(png);
  const out = new PNG({ width: src.width, height: src.height, colorType: 2 });
  for (let i = 0; i < src.data.length; i += 4) {
    const a = src.data[i + 3] / 255;
    out.data[i] = Math.round(src.data[i] * a + 0x16 * (1 - a));
    out.data[i + 1] = Math.round(src.data[i + 1] * a + 0x7a * (1 - a));
    out.data[i + 2] = Math.round(src.data[i + 2] * a + 0x3a * (1 - a));
    out.data[i + 3] = 255;
  }
  return PNG.sync.write(out, { colorType: 2 });
}

function write(path, data) {
  const full = join(root, path);
  mkdirSync(dirname(full), { recursive: true });
  writeFileSync(full, data);
  console.log(path);
}

// Android: densidades y su factor sobre mdpi.
const densities = { mdpi: 1, hdpi: 1.5, xhdpi: 2, xxhdpi: 3, xxxhdpi: 4 };
const res = 'android/app/src/main/res';
for (const [d, f] of Object.entries(densities)) {
  write(`${res}/mipmap-${d}/ic_launcher.png`, render(svgs.icono, 48 * f));
  write(`${res}/mipmap-${d}/ic_launcher_foreground.png`, render(svgs.frente, 108 * f));
  write(`${res}/drawable-${d}/splash_icon.png`, render(svgs.splash, 160 * f));
  write(`${res}/drawable-${d}/ic_notification.png`, render(svgs.notificacion, 24 * f));
}

// iOS: cada archivo del AppIcon según el tamaño de su nombre.
const appIcon = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
for (const file of readdirSync(join(root, appIcon)).filter((f) => f.endsWith('.png'))) {
  const [, size, scale] = file.match(/Icon-App-([\d.]+)x[\d.]+@(\d)x\.png/);
  write(`${appIcon}/${file}`, opaque(render(svgs.tienda, Math.round(size * scale))));
}
const launch = 'ios/Runner/Assets.xcassets/LaunchImage.imageset';
write(`${launch}/LaunchImage.png`, render(svgs.splash, 160));
write(`${launch}/LaunchImage@2x.png`, render(svgs.splash, 320));
write(`${launch}/LaunchImage@3x.png`, render(svgs.splash, 480));

// Web.
write('web/favicon.png', render(svgs.favicon, 32));
copyFileSync(join(root, 'assets/brand/tuku-favicon.svg'), join(root, 'web/favicon.svg'));
write('web/icons/Icon-192.png', render(svgs.icono, 192));
write('web/icons/Icon-512.png', render(svgs.icono, 512));
write('web/icons/Icon-maskable-192.png', render(svgs.maskable, 192));
write('web/icons/Icon-maskable-512.png', render(svgs.maskable, 512));
write('web/icons/apple-touch-icon.png', opaque(render(svgs.tienda, 180)));
write('web/icons/splash.png', render(svgs.splash, 320));

// Imágenes de la app (1x, 2x y 3x).
for (const [name, svg, width] of [
  ['tuku-splash', svgs.splash, 160],
  ['tuku-logo', svgs.logo, 120],
  ['tuku-logo-blanco', svgs.logoBlanco, 120],
]) {
  write(`assets/images/${name}.png`, render(svg, width));
  write(`assets/images/2.0x/${name}.png`, render(svg, width * 2));
  write(`assets/images/3.0x/${name}.png`, render(svg, width * 3));
}
