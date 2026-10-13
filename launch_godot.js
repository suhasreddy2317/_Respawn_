const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');

const candidates = [
  'C:\\Users\\Admin\\OneDrive\\Desktop\\Godot_v4.7.2-stable_win64.exe\\Godot_v4.7.2-stable_win64.exe',
  'C:\\Users\\Admin\\OneDrive\\Desktop\\Godot_v4.7.2-stable_win64.exe\\Godot_v4.7.2-stable_win64_console.exe',
  process.env.GODOT_PATH,
  'godot'
].filter(Boolean);

let godotPath = null;
for (const p of candidates) {
  if (p === 'godot' || fs.existsSync(p)) {
    godotPath = p;
    break;
  }
}

if (!godotPath) {
  console.error('Godot executable not found.');
  process.exit(1);
}

console.log(`\n🎮 Launching RESPAWN: PARALLAX in Godot 4.7.2...`);
console.log(`Binary: ${godotPath}`);
console.log(`Project: ${process.cwd()}\n`);

const child = spawn(godotPath, ['--path', process.cwd()], {
  stdio: 'inherit',
  shell: false
});

child.on('exit', (code) => {
  process.exit(code || 0);
});
