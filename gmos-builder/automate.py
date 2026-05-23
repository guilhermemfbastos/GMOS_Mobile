import time
import sys
from vncdotool import api

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
    client.type("curl -s http://10.0.2.2:8000/gmos-builder/customize.sh | bash\n")
    time.sleep(5)
    
    print("Fechando o terminal...")
    client.type("exit\n")
    
    print("Customização concluída!")

if __name__ == '__main__':
    main()
