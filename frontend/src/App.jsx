import React, { useState, useEffect } from 'react';
import { Shield, ShieldAlert, ShieldCheck, Activity, Terminal, Database, FileText, AlertTriangle, CheckCircle, XCircle, Send, Play } from 'lucide-react';

const App = () => {
  const [prompt, setPrompt] = useState('');
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState(null);
  const [logs, setLogs] = useState([]);
  const [pipelineState, setPipelineState] = useState(0); // 0-4 steps

  const fetchLogs = async () => {
    try {
      const response = await fetch('http://localhost:8000/logs');
      const data = await response.json();
      setLogs(data);
    } catch (err) {
      console.error('Failed to fetch logs:', err);
    }
  };

  useEffect(() => {
    fetchLogs();
  }, []);

  const handleEvaluate = async () => {
    if (!prompt) return;
    setLoading(true);
    setResult(null);
    setPipelineState(1);

    try {
      // Simulate pipeline animation
      const steps = [1, 2, 3, 4];
      for (const step of steps) {
        setPipelineState(step);
        await new Promise(r => setTimeout(r, 600));
      }

      const response = await fetch('http://localhost:8000/evaluate', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ prompt }),
      });
      const data = await response.json();
      setResult(data);
      fetchLogs();
    } catch (err) {
      console.error('Evaluation failed:', err);
      alert('Backend connection failed. Make sure FastAPI server is running.');
    } finally {
      setLoading(false);
    }
  };

  const getDecisionBadge = (decision) => {
    switch (decision) {
      case 'ALLOW': return <span className="badge badge-allow"><CheckCircle size={12} style={{marginRight: 4}}/> ALLOW</span>;
      case 'BLOCK': return <span className="badge badge-block"><XCircle size={12} style={{marginRight: 4}}/> BLOCK</span>;
      case 'WARN': return <span className="badge badge-warn"><AlertTriangle size={12} style={{marginRight: 4}}/> WARN</span>;
      default: return null;
    }
  };

  return (
    <div className="container">
      <header>
        <div className="logo">
          <Shield style={{verticalAlign: 'middle', marginRight: 10}}/>
          GUARDIAN AGENT
        </div>
        <div style={{color: 'var(--text-secondary)', fontSize: '0.9rem'}}>
          Self-Defending AI System v1.0
        </div>
      </header>

      <div className="input-section">
        <h3 style={{marginBottom: '1rem'}}>Defensive Prompt Evaluation</h3>
        <textarea 
          className="prompt-input"
          placeholder="Enter agent command (e.g., 'Summarize system_config.txt' or 'Delete all files in root')"
          value={prompt}
          onChange={(e) => setPrompt(e.target.value)}
          disabled={loading}
        />
        <button 
          className="btn" 
          onClick={handleEvaluate} 
          disabled={loading || !prompt}
        >
          {loading ? (
            <>Analyzing <div className="loading-dots"><div className="dot"></div><div className="dot"></div><div className="dot"></div></div></>
          ) : (
            <><Send size={18}/> Evaluate Security</>
          )}
        </button>
      </div>

      <div className="dashboard-grid">
        <section>
          {result ? (
            <div className="report-card">
              <div style={{display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1.5rem'}}>
                <h3 style={{display: 'flex', alignItems: 'center', gap: 10}}>
                  <ShieldCheck color="var(--accent-blue)"/> Explainability Report
                </h3>
                {getDecisionBadge(result.decision)}
              </div>

              <div className="pipeline">
                <div className={`pipeline-step ${pipelineState >= 1 ? 'active success' : ''}`}></div>
                <div className={`pipeline-step ${pipelineState >= 2 ? 'active success' : ''}`}></div>
                <div className={`pipeline-step ${pipelineState >= 3 ? 'active success' : ''}`}></div>
                <div className={`pipeline-step ${pipelineState >= 4 ? 'active success' : ''}`}></div>
              </div>

              <pre className="report-content">
                {result.explainability_report}
              </pre>

              <div className="meta-grid">
                <div className="meta-item">
                  <div className="meta-label">Action Type</div>
                  <div className="meta-value">{result.intent.action_type.toUpperCase()}</div>
                </div>
                <div className="meta-item">
                  <div className="meta-label">Risk Level</div>
                  <div className="meta-value" style={{color: result.simulation.risk_level === 'HIGH' ? 'var(--accent-red)' : result.simulation.risk_level === 'MEDIUM' ? 'var(--accent-yellow)' : 'var(--accent-green)'}}>
                    {result.simulation.risk_level}
                  </div>
                </div>
                <div className="meta-item">
                  <div className="meta-label">Intent Confidence</div>
                  <div className="meta-value">{(result.intent.confidence * 100).toFixed(1)}%</div>
                </div>
                <div className="meta-item">
                  <div className="meta-label">ArmorClaw Safety</div>
                  <div className="meta-value" style={{color: result.armor_claw.is_safe ? 'var(--accent-green)' : 'var(--accent-red)'}}>
                    {(result.armor_claw.safety_score * 100).toFixed(1)}%
                  </div>
                </div>
                <div className="meta-item">
                  <div className="meta-label">Drift Score</div>
                  <div className="meta-value">{result.drift.drift_score.toFixed(3)}</div>
                </div>
              </div>

              {result.execution && result.execution.executed && (
                <div style={{marginTop: '2rem', padding: '1.5rem', background: 'rgba(63, 185, 80, 0.05)', borderRadius: 8, border: '1px solid var(--accent-green)'}}>
                  <h4 style={{color: 'var(--accent-green)', marginBottom: '0.5rem'}}>Output Execution</h4>
                  <div style={{fontSize: '0.9rem', opacity: 0.9}}>{result.execution.output}</div>
                  <div style={{fontSize: '0.7rem', color: 'var(--text-secondary)', marginTop: '0.5rem'}}>Trace ID: {result.execution.openclaw_trace_id}</div>
                </div>
              )}
            </div>
          ) : (
            <div className="report-card" style={{display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', minHeight: 400, opacity: 0.5}}>
              <Activity size={48} style={{marginBottom: '1rem'}}/>
              <p>Waiting for analysis...</p>
            </div>
          )}
        </section>

        <section>
          <div className="logs-title">
            <h3 style={{display: 'flex', alignItems: 'center', gap: 10}}><Database size={20}/> Session Logs</h3>
            <span style={{fontSize: '0.7rem', opacity: 0.5}}>{logs.length} events</span>
          </div>
          <div className="log-list">
            {logs.length > 0 ? logs.map((log, i) => (
              <div key={i} className="log-item" onClick={() => setResult(log)}>
                <div style={{display: 'flex', justifyContent: 'space-between', marginBottom: '0.5rem'}}>
                  <span style={{fontWeight: 600, color: 'var(--accent-blue)'}}>{log.intent.action_type}</span>
                  <span style={{fontSize: '0.7rem', opacity: 0.5}}>{new Date(log.timestamp).toLocaleTimeString()}</span>
                </div>
                <div style={{fontSize: '0.8rem', opacity: 0.8, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis'}}>
                  {log.raw_prompt}
                </div>
                <div style={{marginTop: '0.5rem'}}>
                  {getDecisionBadge(log.policy.decision)}
                </div>
              </div>
            )) : (
              <p style={{fontSize: '0.9rem', opacity: 0.5, textAlign: 'center', marginTop: '2rem'}}>No logs yet.</p>
            )}
          </div>
        </section>
      </div>
    </div>
  );
};

export default App;
