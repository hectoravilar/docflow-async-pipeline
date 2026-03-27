import { useState } from 'react';
import './App.css';

function App() {
  const [file, setFile] = useState(null);
  const [status, setStatus] = useState('idle'); // idle, uploading, success, error
  const [message, setMessage] = useState('');

  // A sua URL real do API Gateway!
  const API_ENDPOINT = "https://1mh4vq4ac1.execute-api.us-east-1.amazonaws.com/upload";

  const handleFileChange = (e) => {
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
      setMessage('1/2: Solicitando link seguro de upload para a AWS Lambda...');

      // Passo 1: Pede a URL pre-assinada pro seu API Gateway
      const apiResponse = await fetch(API_ENDPOINT, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ filename: file.name }),
      });

      if (!apiResponse.ok) throw new Error('Falha ao pegar as credenciais de upload na API');
      
      const { url, fields } = await apiResponse.json();

      setMessage('2/2: Enviando arquivo direto para o Amazon S3...');

      // Passo 2: Monta o formulário exato que a AWS S3 exige
      const formData = new FormData();
      
      // CRÍTICO: A AWS exige que os campos de segurança venham ANTES do arquivo
      Object.entries(fields).forEach(([key, value]) => {
        formData.append(key, value);
      });
      
      // O arquivo tem que ser o último item anexado!
      formData.append('file', file);

      // Passo 3: Faz o upload direto pro S3
      const s3Response = await fetch(url, {
        method: 'POST',
        body: formData,
      });

      if (s3Response.ok || s3Response.status === 204) {
        setStatus('success');
        setMessage(`Sucesso! O arquivo "${file.name}" foi enviado com segurança para o S3.`);
        setFile(null);
      } else {
        throw new Error('O upload direto pro S3 falhou');
      }

    } catch (error) {
      console.error(error);
      setStatus('error');
      setMessage(error.message || 'Ocorreu um erro durante o upload.');
    }
  };

  return (
    <div style={{ maxWidth: '600px', margin: '50px auto', fontFamily: 'sans-serif', textAlign: 'center' }}>
      <h1>Docflow</h1>
      <p>Pipeline Assíncrono de Processamento de Documentos</p>

      <div style={{ padding: '20px', border: '1px solid #ccc', borderRadius: '8px', marginTop: '20px' }}>
        <input 
          type="file" 
          accept="application/pdf" 
          onChange={handleFileChange}
          disabled={status === 'uploading'}
          style={{ marginBottom: '20px' }}
        />
        <br />
        <button 
          onClick={handleUpload} 
          disabled={!file || status === 'uploading'}
          style={{ padding: '10px 20px', cursor: 'pointer', backgroundColor: '#007bff', color: 'white', border: 'none', borderRadius: '4px' }}
        >
          {status === 'uploading' ? 'Processando...' : 'Fazer Upload para AWS S3'}
        </button>

        {message && (
          <div style={{ marginTop: '20px', padding: '10px', backgroundColor: status === 'error' ? '#ffebee' : '#e8f5e9', color: status === 'error' ? '#c62828' : '#2e7d32', borderRadius: '4px' }}>
            {message}
          </div>
        )}
      </div>
    </div>
  );
}

export default App;