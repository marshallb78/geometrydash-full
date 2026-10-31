const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = process.env.PORT || 8080;
const ROOT = path.resolve(__dirname, '..');

const MIME = {
    '.html': 'text/html; charset=utf-8',
    '.css': 'text/css; charset=utf-8',
    '.js': 'application/javascript; charset=utf-8',
    '.json': 'application/json; charset=utf-8',
    '.png': 'image/png',
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.mp3': 'audio/mpeg',
    '.ogg': 'audio/ogg',
    '.wav': 'audio/wav',
    '.txt': 'text/plain; charset=utf-8',
    '.fnt': 'text/plain; charset=utf-8',
    '.ico': 'image/x-icon',
    '.svg': 'image/svg+xml',
    '.wasm': 'application/wasm'
};

http.createServer((req, res) => {
    const cleanUrl = decodeURIComponent(req.url.split('?')[0]);
    const relPath = cleanUrl === '/' ? '/index.html' : cleanUrl;
    const filePath = path.join(ROOT, relPath);
    if (!filePath.startsWith(ROOT)) {
        res.writeHead(403);
        return res.end('Forbidden');
    }
    fs.stat(filePath, (err, stat) => {
        if (err || !stat.isFile()) {
            res.writeHead(404);
            return res.end('Not found');
        }
        const ext = path.extname(filePath).toLowerCase();
        res.writeHead(200, {
            'Content-Type': MIME[ext] || 'application/octet-stream',
            'Cache-Control': 'no-cache'
        });
        fs.createReadStream(filePath).pipe(res);
    });
}).listen(PORT, () => {
    console.log(`Geometry Dash Web Server running at http://localhost:${PORT}`);
});

