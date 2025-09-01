import React from 'react';
import './App.css';

function App() {
  return (
    <div className="App">
      <header className="App-header">
        <div className="hero-section">
          <div className="hero-background"></div>
          <div className="container">
            <h1 className="logo">🔒 ZamaFundVault</h1>
            <p className="subtitle">Confidential Investment Platform</p>
            <p className="description">
              Revolutionary fundraising platform using Zama's FHE technology for completely private investments
            </p>
            
            <div className="features-grid">
              <div className="feature-card gradient-border card-hover">
                <h3>🔐 Private Investments</h3>
                <p>All investment amounts encrypted using Zama FHE</p>
              </div>
              
              <div className="feature-card gradient-border card-hover">
                <h3>🔄 Secret DEX</h3>
                <p>Trade tokens with complete privacy on SecretSwap</p>
              </div>
              
              <div className="feature-card gradient-border card-hover">
                <h3>🏛️ Decentralized</h3>
                <p>Community-governed platform with transparent operations</p>
              </div>
            </div>
            
            <div className="action-buttons">
              <button className="btn-primary glow-effect" onClick={() => window.location.href = '/secretswap.html'}>
                Launch SecretSwap DEX
              </button>
              <button className="btn-secondary" onClick={() => alert('Connect your Web3 wallet to begin!')}>
                Connect Wallet
              </button>
            </div>
            
            <div className="privacy-notice">
              <span className="privacy-icon">🛡️</span>
              <p>Your financial privacy is our priority. All sensitive data is encrypted using military-grade FHE technology.</p>
            </div>
          </div>
        </div>
        
        <div className="stats-section">
          <div className="container">
            <div className="stats-grid">
              <div className="stat-item">
                <div className="stat-value">***</div>
                <div className="stat-label">Total Raised</div>
              </div>
              <div className="stat-item">
                <div className="stat-value">***</div>
                <div className="stat-label">Active Campaigns</div>
              </div>
              <div className="stat-item">
                <div className="stat-value">***</div>
                <div className="stat-label">Private Investors</div>
              </div>
              <div className="stat-item">
                <div className="stat-value">🔒</div>
                <div className="stat-label">Privacy Level</div>
              </div>
            </div>
          </div>
        </div>
      </header>
    </div>
  );
}

export default App;