#!/usr/bin/env python3
"""
GM OS Web Interface Backend
Ponte entre a interface HTML/JS e o Kernel/Sistema Debian
"""

from flask import Flask, jsonify, request, send_from_directory
import subprocess
import os
import psutil
import socket
import time

app = Flask(__name__, static_folder='.', static_url_path='')

@app.route('/')
def index():
    return send_from_directory('.', 'index.html')

@app.route('/api/status')
def get_status():
    """Retorna status do sistema obtido diretamente do kernel"""
    try:
        # Informações do hostname
        hostname = socket.gethostname()
        
        # Uptime do sistema
        uptime_seconds = time.time() - psutil.boot_time()
        days = int(uptime_seconds // 86400)
        hours = int((uptime_seconds % 86400) // 3600)
        minutes = int((uptime_seconds % 3600) // 60)
        uptime_str = f"{days}d {hours}h {minutes}m"
        
        # Uso de CPU
        cpu_percent = psutil.cpu_percent(interval=1)
        
        # Uso de Memória
        mem = psutil.virtual_memory()
        mem_percent = mem.percent
        mem_used = round(mem.used / (1024**3), 2)
        mem_total = round(mem.total / (1024**3), 2)
        mem_str = f"{mem_used}GB / {mem_total}GB ({mem_percent}%)"
        
        # Uso de Disco
        disk = psutil.disk_usage('/')
        disk_percent = disk.percent
        disk_used = round(disk.used / (1024**3), 2)
        disk_total = round(disk.total / (1024**3), 2)
        disk_str = f"{disk_used}GB / {disk_total}GB ({disk_percent}%)"
        
        return jsonify({
            'hostname': hostname,
            'uptime': uptime_str,
            'cpu': cpu_percent,
            'memory': mem_str,
            'disk': disk_str,
            'kernel': os.uname().release
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/run', methods=['POST'])
def run_command():
    """Executa comandos no shell do Debian e retorna o output"""
    data = request.json
    command = data.get('command', '')
    
    if not command:
        return jsonify({'output': 'Nenhum comando fornecido'}), 400
    
    # Lista de comandos permitidos (segurança básica)
    allowed_prefixes = ['ls', 'cat', 'echo', 'pwd', 'whoami', 'date', 'uname', 
                        'free', 'df', 'top', 'ps', 'kill', 'systemctl', 'apt', 
                        'sudo', 'cd', 'mkdir', 'rm', 'cp', 'mv', 'grep', 'find']
    
    cmd_parts = command.split()
    if not cmd_parts or not any(command.startswith(p) for p in allowed_prefixes):
        return jsonify({'output': 'Comando não permitido por segurança'}), 403
    
    try:
        # Executa o comando no shell
        result = subprocess.run(
            command,
            shell=True,
            capture_output=True,
            text=True,
            timeout=30
        )
        output = result.stdout if result.stdout else result.stderr
        if not output:
            output = f"[Comando executado com código de saída: {result.returncode}]"
        return jsonify({'output': output})
    except subprocess.TimeoutExpired:
        return jsonify({'output': 'Erro: Tempo limite excedido (30s)'}), 408
    except Exception as e:
        return jsonify({'output': f'Erro: {str(e)}'}), 500

if __name__ == '__main__':
    print("🚀 Iniciando GM OS Web Interface...")
    print("📡 Backend conectado ao Kernel Linux")
    print("🌐 Acessível em: http://localhost:5000")
    app.run(host='0.0.0.0', port=5000, debug=False)
