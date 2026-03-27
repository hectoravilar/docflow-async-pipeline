import { useState, useRef } from 'react';

function App() {
  const [file, setFile] = useState(null);
  const [status, setStatus] = useState('idle'); // idle, uploading, success, error
  const [message, setMessage] = useState('');
  const [dragActive, setDragActive] = useState(false);
  const inputRef = useRef(null);

  const API_ENDPOINT = "https://1mh4vq4ac1.execute-api.us-east-1.amazonaws.com/upload";

  // Gerencia os eventos de Arrastar e Soltar (Drag & Drop)
  const handleDrag = (e) => {
    e.preventDefault();
    e.stopPropagation();
    if (e.type === "dragenter" || e.type === "dragover") {
      setDragActive(true);
    } else if (e.type === "dragleave") {
      setDragActive(false);
    }
  };

  const handleDrop = (e) => {
    e.preventDefault();
    e.stopPropagation();
    setDragActive(false);
    if (e.dataTransfer.files && e.dataTransfer.files[0]) {
      const droppedFile = e.dataTransfer.files[0];
      if (droppedFile.type === "application/pdf") {
        setFile(droppedFile);
        setStatus('idle');
        setMessage('');
      } else {
        setStatus('error');
        setMessage('Por favor, envie apenas arquivos PDF.');
      }
    }
  };

  const handleChange = (e) => {
    e.preventDefault();
    if (e.target.files && e.target.files[0]) {
      setFile(e.target.files[0]);
      setStatus('idle');
      setMessage('');
    }
  };

  const handleUpload = async () => {
    if (!file) return;

    try {
      setStatus('uploading');
      setMessage('Gerando credenciais seguras na AWS...');

      const apiResponse = await fetch(API_ENDPOINT, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ filename: file.name }),
      });

      if (!apiResponse.ok) throw new Error('Falha de autorização na API.');
      
      const { url, fields } = await apiResponse.json();

      setMessage('Transferindo arquivo para o S3...');

      const formData = new FormData();
      Object.entries(fields).forEach(([key, value]) => formData.append(key, value));
      formData.append('file', file);

      const s3Response = await fetch(url, {
        method: 'POST',
        body: formData,
      });

      if (s3Response.ok || s3Response.status === 204) {
        setStatus('success');
        setMessage('Upload concluído! Documento na fila de processamento.');
        setFile(null);
      } else {
        throw new Error('Falha no upload direto para o S3.');
      }

    } catch (error) {
      console.error(error);
      setStatus('error');
      setMessage(error.message || 'Erro inesperado de rede.');
    }
  };

  return (
    <div className="min-h-screen bg-neutral-950 flex flex-col items-center justify-center p-4 relative overflow-hidden font-sans text-neutral-200">
      
      {/* Efeitos de Luz de Fundo (Glow) */}
      <div className="absolute top-[-10%] left-[-10%] w-96 h-96 bg-blue-600/20 rounded-full blur-[120px] pointer-events-none"></div>
      <div className="absolute bottom-[-10%] right-[-10%] w-96 h-96 bg-cyan-600/20 rounded-full blur-[120px] pointer-events-none"></div>

      <div className="z-10 w-full max-w-lg">
        {/* Cabeçalho */}
        <div className="text-center mb-10">
          <div className="inline-flex items-center justify-center p-3 bg-neutral-900 border border-neutral-800 rounded-xl mb-4 shadow-2xl">
            <svg className="w-8 h-8 text-blue-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 002-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"></path>
            </svg>
          </div>
          <h1 className="text-4xl font-extrabold tracking-tight text-white mb-2">
            Docflow <span className="text-transparent bg-clip-text bg-gradient-to-r from-blue-400 to-cyan-400">Pipeline</span>
          </h1>
          <p className="text-neutral-400 font-medium">Extração de metadados orientada a eventos.</p>
        </div>

        {/* Card Principal */}
        <div className="bg-neutral-900/60 backdrop-blur-xl border border-neutral-800 p-8 rounded-3xl shadow-2xl">
          
          {/* Área de Drag & Drop */}
          <div 
            className={`relative flex flex-col items-center justify-center w-full h-48 border-2 border-dashed rounded-2xl transition-colors duration-200 ease-in-out
              ${dragActive ? 'border-blue-500 bg-blue-500/10' : 'border-neutral-700 hover:border-neutral-500 hover:bg-neutral-800/50'}
              ${status === 'uploading' ? 'opacity-50 pointer-events-none' : 'cursor-pointer'}
            `}
            onDragEnter={handleDrag}
            onDragLeave={handleDrag}
            onDragOver={handleDrag}
            onDrop={handleDrop}
            onClick={() => inputRef.current?.click()}
          >
            <input 
              ref={inputRef}
              type="file" 
              accept="application/pdf" 
              className="hidden" 
              onChange={handleChange}
              disabled={status === 'uploading'}
            />
            
            {!file ? (
              <div className="flex flex-col items-center space-y-3 pointer-events-none">
                <svg className="w-10 h-10 text-neutral-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="1.5" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"></path>
                </svg>
                <p className="text-sm text-neutral-400 font-medium">
                  <span className="text-blue-400">Clique para selecionar</span> ou arraste e solte
                </p>
                <p className="text-xs text-neutral-500">Apenas arquivos PDF (Max 10MB)</p>
              </div>
            ) : (
              <div className="flex flex-col items-center space-y-2 pointer-events-none">
                <svg className="w-10 h-10 text-blue-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="1.5" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path>
                </svg>
                <p className="text-sm font-semibold text-white max-w-[200px] truncate">{file.name}</p>
                <p className="text-xs text-neutral-400">{(file.size / 1024 / 1024).toFixed(2)} MB</p>
              </div>
            )}
          </div>

          {/* Mensagens de Feedback */}
          {message && (
            <div className={`mt-6 p-4 rounded-xl flex items-center space-x-3 text-sm font-medium border transition-all
              ${status === 'uploading' ? 'bg-blue-500/10 border-blue-500/20 text-blue-400' : ''}
              ${status === 'success' ? 'bg-emerald-500/10 border-emerald-500/20 text-emerald-400' : ''}
              ${status === 'error' ? 'bg-red-500/10 border-red-500/20 text-red-400' : ''}
            `}>
              {status === 'uploading' && (
                <svg className="animate-spin h-5 w-5 text-blue-500" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                  <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                  <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                </svg>
              )}
              {status === 'success' && (
                <svg className="h-5 w-5 text-emerald-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M5 13l4 4L19 7" />
                </svg>
              )}
              <span>{message}</span>
            </div>
          )}

          {/* Botão de Upload */}
          <button 
            onClick={handleUpload}
            disabled={!file || status === 'uploading'}
            className={`mt-6 w-full py-4 px-6 rounded-xl font-bold text-white transition-all duration-300 transform
              ${(!file || status === 'uploading') 
                ? 'bg-neutral-800 text-neutral-500 cursor-not-allowed' 
                : 'bg-gradient-to-r from-blue-600 to-cyan-600 hover:from-blue-500 hover:to-cyan-500 hover:scale-[1.02] shadow-[0_0_20px_rgba(37,99,235,0.3)] active:scale-95'
              }
            `}
          >
            {status === 'uploading' ? 'Processando...' : 'Iniciar Upload Seguro'}
          </button>

        </div>
        
        {/* Footer */}
        <div className="mt-8 flex items-center justify-center space-x-2 text-xs text-neutral-500">
          <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 24 24">
            <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-1 15h-2v-2h2v2zm0-4h-2V7h2v6z"></path>
          </svg>
          <span>Upload assíncrono via Amazon S3 Presigned URLs</span>
        </div>
      </div>
    </div>
  );
}

export default App;