const fs = require('fs');
const https = require('https');
const os = require('os');
const path = require('path');

const version = require('./package.json').version;
const binDir = path.join(__dirname, 'bin');
if (!fs.existsSync(binDir)) {
  fs.mkdirSync(binDir);
}

const platform = os.platform();
const arch = os.arch();

let artifactName = '';
if (platform === 'linux' && arch === 'x64') {
  artifactName = 'rw_git_mcp_linux_x64';
} else if (platform === 'darwin' && arch === 'arm64') {
  artifactName = 'rw_git_mcp_macos_arm64';
} else if (platform === 'darwin' && arch === 'x64') {
  artifactName = 'rw_git_mcp_macos_x64';
} else if (platform === 'win32' && arch === 'x64') {
  artifactName = 'rw_git_mcp_windows_x64.exe';
} else {
  console.error(`Unsupported platform/architecture: ${platform}/${arch}`);
  process.exit(1);
}

const url = `https://github.com/rw-core/rw-git/releases/download/v${version}/${artifactName}`;
const destPath = path.join(binDir, platform === 'win32' ? 'rw-git-mcp-bin.exe' : 'rw-git-mcp-bin');

console.log(`Downloading ${url} ...`);

https.get(url, (res) => {
  handleResponse(res);
}).on('error', (err) => {
  console.error('Download failed:', err);
  process.exit(1);
});

function handleResponse(res) {
  if (res.statusCode === 302 || res.statusCode === 301) {
    https.get(res.headers.location, (redirectRes) => {
      handleResponse(redirectRes);
    });
  } else if (res.statusCode === 200) {
    saveFile(res);
  } else {
    console.error(`Download failed with status code: ${res.statusCode}`);
    process.exit(1);
  }
}

function saveFile(res) {
  const fileStream = fs.createWriteStream(destPath);
  res.pipe(fileStream);
  fileStream.on('finish', () => {
    fileStream.close();
    if (platform !== 'win32') {
      fs.chmodSync(destPath, 0o755); // Make executable
    }
    console.log('Download complete.');
  });
}
