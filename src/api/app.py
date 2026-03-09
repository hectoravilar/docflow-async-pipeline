import os
from flask import Flask, jsonify
from flask_cors import CORS
from random import randint

app = Flask(__name__)

# Lê a URL do frontend injetada pelo Terraform. Se não achar, libera geral (útil para testes locais)
frontend_url = os.environ.get('FRONTEND_URL', '*')

# Habilita o CORS restringindo apenas para a origem do nosso S3
CORS(app, origins=[frontend_url])

@app.route('/')
def random_number():
    return jsonify({'number': randint(1, 1000)})

@app.route('/health')
def health_check():
    return jsonify({"status": "healthy"}), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
