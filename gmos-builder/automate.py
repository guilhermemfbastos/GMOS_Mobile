import time
import sys
from vncdotool import api

# Mapa de caracteres especiais para nomes de tecla do vncdotool
SHIFT_MAP = {
    '!': 'shift-1',
    '@': 'shift-2',
    '#': 'shift-3',
    '$': 'shift-4',
    '%': 'shift-5',
    '^': 'shift-6',
    '&': 'shift-7',
    '*': 'shift-8',
    '(': 'shift-9',
    ')': 'shift-0',
    '_': 'shift-minus',
    '+': 'shift-=',
    '{': 'shift-[',
    '}': 'shift-]',
    '|': 'shift-bslash',
    ':': 'shift-;',
    '"': "shift-'",
    '<': 'shift-,',
    '>': 'shift-.',
    '?': 'shift-fslash',
    '~': 'shift-`',
}

SPECIAL_MAP = {
    ' ': 'space',
    '\t': 'tab',
    '/': 'fslash',
    '\\': 'bslash',
}

def vnc_type(client, text):
    """Digita texto usando keyPress caractere por caractere."""
    for ch in text:
        if ch in SHIFT_MAP:
            client.keyPress(SHIFT_MAP[ch])
        elif ch in SPECIAL_MAP:
            client.keyPress(SPECIAL_MAP[ch])
        elif ch.isupper():
            client.keyPress(f'shift-{ch.lower()}')
        else:
            client.keyPress(ch)
    time.sleep(0.2)

def main():
    print("Conectando ao VNC em 127.0.0.1:5900...")
    client = None
    for attempt in range(1, 6):
        try:
            client = api.connect('127.0.0.1::5900')
            # vncdotool connects lazily, force the connection by sending a harmless shift key
            client.keyPress('shift')
            print("Conectado com sucesso!")
            break
        except Exception as e:
            print(f"Tentativa {attempt}/5 falhou ao conectar ao VNC: {e}")
            if attempt < 5:
                time.sleep(3)
            else:
                print("Erro: Não foi possível conectar ao VNC após 5 tentativas.")
                sys.exit(1)
        
    print("Enviando comando para garantir foco na janela...")
    client.keyPress('super')  # abre/fecha o menu para dar foco
    time.sleep(1)
    client.keyPress('super')
    time.sleep(1)
    
    print("Enviando Ctrl+Alt+T para abrir o terminal...")
    client.keyPress('ctrl-alt-t')
    time.sleep(3)
    
    print("Executando o script de customização...")
    # Executa o script baixado via HTTP local
    vnc_type(client, "curl -s http:")
    vnc_type(client, "//10.0.2.2:")
    vnc_type(client, "8000/gmos-builder/customize.sh ")
    vnc_type(client, "| bash")
    client.keyPress('enter')
    
    print("Aguardando o script finalizar (15s)...")
    time.sleep(15)
    
    print("Customização concluída!")
    
    print("Iniciando a exportação da ISO para o disco virtual...")
    vnc_type(client, "curl -s http:")
    vnc_type(client, "//10.0.2.2:")
    vnc_type(client, "8000/gmos-builder/prepare_iso.sh ")
    vnc_type(client, "| bash")
    client.keyPress('enter')
    
    print("Aguardando exportação finalizar e a VM desligar (15s)...")
    time.sleep(15)
    # Desconecta de forma limpa para evitar a exceção "Transport endpoint is not connected"
    client.disconnect()

if __name__ == '__main__':
    main()
