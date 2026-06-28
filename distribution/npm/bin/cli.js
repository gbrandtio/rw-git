#!/usr/bin/env node

const path = require('path');
const fs = require('fs');
const { spawn } = require('child_process');
const os = require('os');

const command = process.argv[2];

if (command === 'install-skills') {
  const skillsSourceDir = path.join(__dirname, '../skills');
  const targetDir = path.join(process.cwd(), '.agents', 'skills', 'rw-git-mcp');

  if (!fs.existsSync(skillsSourceDir)) {
    console.error(`Error: Skills directory not found in the package at ${skillsSourceDir}`);
    console.error('This may be a packaging issue.');
    process.exit(1);
  }

  try {
    fs.mkdirSync(targetDir, { recursive: true });
    fs.cpSync(skillsSourceDir, targetDir, { recursive: true });
    console.log(`Successfully installed rw-git-mcp skills to ${targetDir}`);
    process.exit(0);
  } catch (error) {
    console.error(`Failed to copy skills: ${error.message}`);
    process.exit(1);
  }
}

// Proxy to the actual Dart binary
const isWindows = os.platform() === 'win32';
const binName = isWindows ? 'rw-git-mcp-bin.exe' : 'rw-git-mcp-bin';
const binPath = path.join(__dirname, binName);

if (!fs.existsSync(binPath)) {
  console.error(`Error: The executable ${binName} was not found.`);
  console.error('Make sure the postinstall script completed successfully.');
  process.exit(1);
}

// Pass all arguments down, minus the 'node' and 'cli.js' parts
const args = process.argv.slice(2);

const child = spawn(binPath, args, {
  stdio: 'inherit'
});

child.on('error', (err) => {
  console.error(`Failed to start child process: ${err}`);
  process.exit(1);
});

child.on('exit', (code, signal) => {
  if (code !== null) {
    process.exit(code);
  } else if (signal) {
    process.kill(process.pid, signal);
  } else {
    process.exit(0);
  }
});
