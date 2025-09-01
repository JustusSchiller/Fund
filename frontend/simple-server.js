const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = 3017;

const mimeTypes = {
  '.html': 'text/html',
  '.js': 'text/javascript',
  '.css': 'text/css',
  '.json': 'application/json',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.gif': 'image/gif',
  '.ico': 'image/x-icon',
};

const server = http.createServer((req, res) => {
  console.log(`${req.method} ${req.url}`);
  
  let filePath = '.' + req.url;
  if (filePath === './') {
    filePath = './public/index.html';
  }
  
  // If file doesn't exist in public, try src
  if (!fs.existsSync(filePath) && !filePath.includes('public/')) {
    filePath = './src' + req.url.replace('/src', '');
    if (filePath === './src/') {
      filePath = './src/App.js';
    }
  }
  
  const extname = String(path.extname(filePath)).toLowerCase();
  const contentType = mimeTypes[extname] || 'application/octet-stream';

  fs.readFile(filePath, (error, content) => {
    if (error) {
      if(error.code === 'ENOENT') {
        // 404 - serve a simple React app
        const reactApp = `
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ZamaFundVault - Confidential Investment Platform</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { 
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .container { 
            text-align: center; 
            max-width: 800px; 
            padding: 40px;
            background: rgba(255,255,255,0.1);
            border-radius: 20px;
            backdrop-filter: blur(10px);
            box-shadow: 0 8px 32px rgba(31, 38, 135, 0.37);
        }
        h1 { 
            font-size: 3rem; 
            margin-bottom: 1rem;
            background: linear-gradient(45deg, #fff, #f0f8ff);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
        }
        .subtitle { 
            font-size: 1.5rem; 
            margin-bottom: 2rem;
            opacity: 0.9;
        }
        .features { 
            display: grid; 
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); 
            gap: 2rem; 
            margin: 3rem 0;
        }
        .feature { 
            padding: 2rem;
            background: rgba(255,255,255,0.1);
            border-radius: 15px;
            border: 1px solid rgba(255,255,255,0.2);
        }
        .feature h3 { 
            font-size: 1.25rem; 
            margin-bottom: 1rem;
        }
        .buttons { 
            display: flex; 
            gap: 1rem; 
            justify-content: center; 
            flex-wrap: wrap;
            margin-top: 2rem;
        }
        button { 
            padding: 12px 24px; 
            border: none; 
            border-radius: 10px; 
            font-size: 1rem;
            cursor: pointer;
            transition: all 0.3s ease;
        }
        .btn-primary { 
            background: linear-gradient(45deg, #ff6b6b, #ee5a24);
            color: white;
        }
        .btn-secondary { 
            background: rgba(255,255,255,0.2);
            color: white;
            border: 1px solid rgba(255,255,255,0.3);
        }
        button:hover { 
            transform: translateY(-2px);
            box-shadow: 0 5px 15px rgba(0,0,0,0.2);
        }
        .privacy-notice {
            margin-top: 2rem;
            padding: 1rem;
            background: rgba(0,255,0,0.1);
            border-radius: 10px;
            border: 1px solid rgba(0,255,0,0.3);
        }
        .stats {
            display: flex;
            justify-content: space-around;
            margin: 2rem 0;
            text-align: center;
        }
        .stat-item {
            padding: 1rem;
        }
        .stat-value {
            font-size: 2rem;
            font-weight: bold;
        }
        .stat-label {
            opacity: 0.8;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🔒 ZamaFundVault</h1>
        <p class="subtitle">Confidential Investment Platform</p>
        <p>Revolutionary fundraising platform using Zama's FHE technology for completely private investments</p>
        
        <div class="features">
            <div class="feature">
                <h3>🔐 Private Investments</h3>
                <p>All investment amounts encrypted using Zama FHE</p>
            </div>
            <div class="feature">
                <h3>🔄 Secret DEX</h3>
                <p>Trade tokens with complete privacy on SecretSwap</p>
            </div>
            <div class="feature">
                <h3>🏛️ Decentralized</h3>
                <p>Community-governed platform with transparent operations</p>
            </div>
        </div>
        
        <div class="stats">
            <div class="stat-item">
                <div class="stat-value">***</div>
                <div class="stat-label">Total Raised</div>
            </div>
            <div class="stat-item">
                <div class="stat-value">***</div>
                <div class="stat-label">Active Campaigns</div>
            </div>
            <div class="stat-item">
                <div class="stat-value">***</div>
                <div class="stat-label">Private Investors</div>
            </div>
            <div class="stat-item">
                <div class="stat-value">🔒</div>
                <div class="stat-label">Privacy Level</div>
            </div>
        </div>
        
        <div class="buttons">
            <button class="btn-primary" onclick="window.open('secretswap.html', '_blank')">
                Launch SecretSwap DEX
            </button>
            <button class="btn-secondary" onclick="alert('Connect your Web3 wallet to begin!')">
                Connect Wallet
            </button>
        </div>
        
        <div class="privacy-notice">
            <span>🛡️</span>
            <p>Your financial privacy is our priority. All sensitive data is encrypted using military-grade FHE technology.</p>
        </div>
        
        <div style="margin-top: 2rem; opacity: 0.7;">
            <p>🌐 Server running on port 3017 | Network: Local Development | Privacy: Maximum</p>
        </div>
    </div>
</body>
</html>`;
        res.writeHead(200, {'Content-Type': 'text/html'});
        res.end(reactApp, 'utf-8');
      } else {
        res.writeHead(500);
        res.end('Server Error: ' + error.code + ' ..\n');
      }
    } else {
      res.writeHead(200, { 'Content-Type': contentType });
      res.end(content, 'utf-8');
    }
  });
});

server.listen(PORT, () => {
  console.log(`🔒 ZamaFundVault Server running at http://localhost:${PORT}/`);
  console.log('🌐 Frontend Server: http://localhost:3017');
  console.log('🔄 Confidential DEX: http://localhost:3017/secretswap.html');
  console.log('📊 Dashboard: http://localhost:3017');
});