import { mkdir, readFile, writeFile, access } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { dirname, isAbsolute, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const projectRoot = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const outputRoot = join(projectRoot, 'Godot', 'assets', 'third_party', 'poly_haven');
const assetIds = process.argv.length > 2
  ? process.argv.slice(2)
  : ['painted_wooden_cabinet', 'Shelf_01', 'caged_hanging_light', 'small_plastic_torch'];
const headers = { 'User-Agent': 'BlackwebAssetImport/1.0' };

async function getJson(url) {
  const response = await fetch(url, { headers });
  if (!response.ok) throw new Error(`${url}: HTTP ${response.status}`);
  return response.json();
}

async function downloadFile(url, expectedSize, expectedMd5, destination) {
  const response = await fetch(url, { headers });
  if (!response.ok) throw new Error(`${url}: HTTP ${response.status}`);
  const bytes = Buffer.from(await response.arrayBuffer());
  const md5 = createHash('md5').update(bytes).digest('hex');
  if (bytes.length !== expectedSize || md5.toLowerCase() !== expectedMd5.toLowerCase()) {
    throw new Error(`Integrity failure for ${destination}: ${bytes.length} bytes, ${md5}`);
  }
  await mkdir(dirname(destination), { recursive: true });
  await writeFile(destination, bytes);
  return { bytes: bytes.length, md5 };
}

for (const id of assetIds) {
  const [files, info] = await Promise.all([
    getJson(`https://api.polyhaven.com/files/${id}`),
    getJson(`https://api.polyhaven.com/info/${id}`),
  ]);
  const gltfEntry = files.gltf?.['1k']?.gltf;
  if (!gltfEntry) throw new Error(`Missing 1K glTF for ${id}`);
  const assetDirectory = join(outputRoot, id);
  const assetFiles = [[`${id}_1k.gltf`, gltfEntry], ...Object.entries(gltfEntry.include ?? {})];
  const recordedFiles = [];
  for (const [relativePath, metadata] of assetFiles) {
    if (isAbsolute(relativePath) || relativePath.split(/[\\/]/).includes('..')) {
      throw new Error(`Unsafe asset dependency: ${relativePath}`);
    }
    const integrity = await downloadFile(metadata.url, metadata.size, metadata.md5, join(assetDirectory, relativePath));
    recordedFiles.push({ path: relativePath, ...integrity, sourceUrl: metadata.url });
  }
  const gltf = JSON.parse(await readFile(join(assetDirectory, `${id}_1k.gltf`), 'utf8'));
  const uris = [...(gltf.buffers ?? []), ...(gltf.images ?? [])]
    .map((item) => item.uri)
    .filter((uri) => uri && !uri.startsWith('data:'));
  for (const uri of uris) await access(join(assetDirectory, uri));
  const manifest = {
    asset: info.name,
    id,
    creators: Object.keys(info.authors ?? {}),
    sourcePage: `https://polyhaven.com/a/${id}`,
    license: 'CC0',
    licensePage: 'https://polyhaven.com/license',
    resolution: '1K',
    fileCount: recordedFiles.length,
    totalBytes: recordedFiles.reduce((sum, item) => sum + item.bytes, 0),
    files: recordedFiles,
  };
  await writeFile(join(assetDirectory, 'source.json'), `${JSON.stringify(manifest, null, 2)}\n`);
  console.log(`${id}: ${manifest.fileCount} files, ${manifest.totalBytes} bytes, ${uris.length} glTF dependencies resolved`);
}
