#!/bin/bash
set -euo pipefail

# =============================
# Gerenciador Avançado de Múltiplas VMs
# =============================

# Função para exibir cabeçalho
display_header() {
    clear
    cat << "EOF"
========================================================================
Patrocinado por esses caras!                                                                  
HOPINGBOYZ
Jishnu
NotGamerPie
========================================================================
EOF
    echo
}

# Função para exibir saída colorida
print_status() {
    local type=$1
    local message=$2
    
    case $type in
        "INFO") echo -e "\033[1;34m[INFO]\033[0m $message" ;;
        "WARN") echo -e "\033[1;33m[AVISO]\033[0m $message" ;;
        "ERROR") echo -e "\033[1;31m[ERRO]\033[0m $message" ;;
        "SUCCESS") echo -e "\033[1;32m[SUCESSO]\033[0m $message" ;;
        "INPUT") echo -e "\033[1;36m[ENTRADA]\033[0m $message" ;;
        *) echo "[$type] $message" ;;
    esac
}

# Função para validar entrada
validate_input() {
    local type=$1
    local value=$2
    
    case $type in
        "number")
            if ! [[ "$value" =~ ^[0-9]+$ ]]; then
                print_status "ERROR" "Deve ser um número"
                return 1
            fi
            ;;
        "size")
            if ! [[ "$value" =~ ^[0-9]+[GgMm]$ ]]; then
                print_status "ERROR" "Deve ser um tamanho com unidade (ex.: 100G, 512M)"
                return 1
            fi
            ;;
        "port")
            if ! [[ "$value" =~ ^[0-9]+$ ]] || [ "$value" -lt 23 ] || [ "$value" -gt 65535 ]; then
                print_status "ERROR" "Deve ser um número de porta válido (23-65535)"
                return 1
            fi
            ;;
        "name")
            if ! [[ "$value" =~ ^[a-zA-Z0-9_-]+$ ]]; then
                print_status "ERROR" "Nome da VM só pode conter letras, números, hífens e underscores"
                return 1
            fi
            ;;
        "username")
            if ! [[ "$value" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
                print_status "ERROR" "Nome de usuário deve começar com letra ou underscore, e conter apenas letras, números, hífens e underscores"
                return 1
            fi
            ;;
    esac
    return 0
}

# Função para verificar dependências
check_dependencies() {
    local deps=("qemu-system-x86_64" "wget" "cloud-localds" "qemu-img")
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_status "ERROR" "Dependências ausentes: ${missing_deps[*]}"
        print_status "INFO" "No Ubuntu/Debian, tente: sudo apt install qemu-system cloud-image-utils wget"
        exit 1
    fi
}

# Função para limpar arquivos temporários
cleanup() {
    if [ -f "user-data" ]; then rm -f "user-data"; fi
    if [ -f "meta-data" ]; then rm -f "meta-data"; fi
}

# Função para obter todas as configurações de VMs
get_vm_list() {
    find "$VM_DIR" -name "*.conf" -exec basename {} .conf \; 2>/dev/null | sort
}

# Função para carregar configuração de VM
load_vm_config() {
    local vm_name=$1
    local config_file="$VM_DIR/$vm_name.conf"
    
    if [[ -f "$config_file" ]]; then
        # Limpar variáveis anteriores
        unset VM_NAME OS_TYPE CODENAME IMG_URL HOSTNAME USERNAME PASSWORD
        unset DISK_SIZE MEMORY CPUS SSH_PORT GUI_MODE PORT_FORWARDS IMG_FILE SEED_FILE CREATED
        
        source "$config_file"
        return 0
    else
        print_status "ERROR" "Configuração para VM '$vm_name' não encontrada"
        return 1
    fi
}

# Função para salvar configuração de VM
save_vm_config() {
    local config_file="$VM_DIR/$VM_NAME.conf"
    
    cat > "$config_file" <<EOF
VM_NAME="$VM_NAME"
OS_TYPE="$OS_TYPE"
CODENAME="$CODENAME"
IMG_URL="$IMG_URL"
HOSTNAME="$HOSTNAME"
USERNAME="$USERNAME"
PASSWORD="$PASSWORD"
DISK_SIZE="$DISK_SIZE"
MEMORY="$MEMORY"
CPUS="$CPUS"
SSH_PORT="$SSH_PORT"
GUI_MODE="$GUI_MODE"
PORT_FORWARDS="$PORT_FORWARDS"
IMG_FILE="$IMG_FILE"
SEED_FILE="$SEED_FILE"
CREATED="$CREATED"
EOF
    
    print_status "SUCCESS" "Configuração salva em $config_file"
}

# Função para criar nova VM
create_new_vm() {
    print_status "INFO" "Criando uma nova VM"
    
    # Seleção de OS
    print_status "INFO" "Selecione um SO para configurar:"
    local os_options=()
    local i=1
    for os in "${!OS_OPTIONS[@]}"; do
        echo "  $i) $os"
        os_options[$i]="$os"
        ((i++))
    done
    
    while true; do
        read -p "$(print_status "INPUT" "Digite sua escolha (1-${#OS_OPTIONS[@]}): ")" choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#OS_OPTIONS[@]} ]; then
            local os="${os_options[$choice]}"
            IFS='|' read -r OS_TYPE CODENAME IMG_URL DEFAULT_HOSTNAME DEFAULT_USERNAME DEFAULT_PASSWORD <<< "${OS_OPTIONS[$os]}"
            break
        else
            print_status "ERROR" "Seleção inválida. Tente novamente."
        fi
    done

    # Entradas personalizadas com validação
    while true; do
        read -p "$(print_status "INPUT" "Digite o nome da VM (padrão: $DEFAULT_HOSTNAME): ")" VM_NAME
        VM_NAME="${VM_NAME:-$DEFAULT_HOSTNAME}"
        if validate_input "name" "$VM_NAME"; then
            # Verificar se o nome da VM já existe
            if [[ -f "$VM_DIR/$VM_NAME.conf" ]]; then
                print_status "ERROR" "VM com nome '$VM_NAME' já existe"
            else
                break
            fi
        fi
    done

    while true; do
        read -p "$(print_status "INPUT" "Digite o hostname (padrão: $VM_NAME): ")" HOSTNAME
        HOSTNAME="${HOSTNAME:-$VM_NAME}"
        if validate_input "name" "$HOSTNAME"; then
            break
        fi
    done

    while true; do
        read -p "$(print_status "INPUT" "Digite o nome de usuário (padrão: $DEFAULT_USERNAME): ")" USERNAME
        USERNAME="${USERNAME:-$DEFAULT_USERNAME}"
        if validate_input "username" "$USERNAME"; then
            break
        fi
    done

    while true; do
        read -s -p "$(print_status "INPUT" "Digite a senha (padrão: $DEFAULT_PASSWORD): ")" PASSWORD
        PASSWORD="${PASSWORD:-$DEFAULT_PASSWORD}"
        echo
        if [ -n "$PASSWORD" ]; then
            break
        else
            print_status "ERROR" "A senha não pode ser vazia"
        fi
    done

    while true; do
        read -p "$(print_status "INPUT" "Tamanho do disco (padrão: 20G): ")" DISK_SIZE
        DISK_SIZE="${DISK_SIZE:-20G}"
        if validate_input "size" "$DISK_SIZE"; then
            break
        fi
    done

    while true; do
        read -p "$(print_status "INPUT" "Memória em MB (padrão: 2048): ")" MEMORY
        MEMORY="${MEMORY:-2048}"
        if validate_input "number" "$MEMORY"; then
            break
        fi
    done

    while true; do
        read -p "$(print_status "INPUT" "Número de CPUs (padrão: 2): ")" CPUS
        CPUS="${CPUS:-2}"
        if validate_input "number" "$CPUS"; then
            break
        fi
    done

    while true; do
        read -p "$(print_status "INPUT" "Porta SSH (padrão: 2222): ")" SSH_PORT
        SSH_PORT="${SSH_PORT:-2222}"
        if validate_input "port" "$SSH_PORT"; then
            # Verificar se a porta já está em uso
            if ss -tln 2>/dev/null | grep -q ":$SSH_PORT "; then
                print_status "ERROR" "A porta $SSH_PORT já está em uso"
            else
                break
            fi
        fi
    done

    while true; do
        read -p "$(print_status "INPUT" "Ativar modo GUI? (s/n, padrão: n): ")" gui_input
        GUI_MODE=false
        gui_input="${gui_input:-n}"
        if [[ "$gui_input" =~ ^[YySs]$ ]]; then 
            GUI_MODE=true
            break
        elif [[ "$gui_input" =~ ^[Nn]$ ]]; then
            break
        else
            print_status "ERROR" "Por favor, responda s ou n"
        fi
    done

    # Opções de rede adicionais
    read -p "$(print_status "INPUT" "Redirecionamentos de porta adicionais (ex.: 8080:80, Enter para nenhum): ")" PORT_FORWARDS

    IMG_FILE="$VM_DIR/$VM_NAME.img"
    SEED_FILE="$VM_DIR/$VM_NAME-seed.iso"
    CREATED="$(date)"

    # Baixar e configurar imagem da VM
    setup_vm_image
    
    # Salvar configuração
    save_vm_config
}

# Função para configurar imagem da VM
setup_vm_image() {
    print_status "INFO" "Baixando e preparando imagem..."
    
    # Criar diretório da VM se não existir
    mkdir -p "$VM_DIR"
    
    # Verificar se a imagem já existe
    if [[ -f "$IMG_FILE" ]]; then
        print_status "INFO" "Arquivo de imagem já existe. Pulando download."
    else
        print_status "INFO" "Baixando imagem de $IMG_URL..."
        if ! wget --progress=bar:force "$IMG_URL" -O "$IMG_FILE.tmp"; then
            print_status "ERROR" "Falha ao baixar imagem de $IMG_URL"
            exit 1
        fi
        mv "$IMG_FILE.tmp" "$IMG_FILE"
    fi
    
    # Redimensionar imagem do disco se necessário
    if ! qemu-img resize "$IMG_FILE" "$DISK_SIZE" 2>/dev/null; then
        print_status "WARN" "Falha ao redimensionar imagem do disco. Criando nova imagem com tamanho especificado..."
        # Criar nova imagem com o tamanho especificado
        rm -f "$IMG_FILE"
        qemu-img create -f qcow2 -F qcow2 -b "$IMG_FILE" "$IMG_FILE.tmp" "$DISK_SIZE" 2>/dev/null || \
        qemu-img create -f qcow2 "$IMG_FILE" "$DISK_SIZE"
        if [ -f "$IMG_FILE.tmp" ]; then
            mv "$IMG_FILE.tmp" "$IMG_FILE"
        fi
    fi

    # Configuração cloud-init
    cat > user-data <<EOF
#cloud-config
hostname: $HOSTNAME
ssh_pwauth: true
disable_root: false
users:
  - name: $USERNAME
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    password: $(openssl passwd -6 "$PASSWORD" | tr -d '\n')
chpasswd:
  list: |
    root:$PASSWORD
    $USERNAME:$PASSWORD
  expire: false
EOF

    cat > meta-data <<EOF
instance-id: iid-$VM_NAME
local-hostname: $HOSTNAME
EOF

    if ! cloud-localds "$SEED_FILE" user-data meta-data; then
        print_status "ERROR" "Falha ao criar imagem de seed do cloud-init"
        exit 1
    fi
    
    print_status "SUCCESS" "VM '$VM_NAME' criada com sucesso."
}

# Função para iniciar uma VM
start_vm() {
    local vm_name=$1
    
    if load_vm_config "$vm_name"; then
        print_status "INFO" "Iniciando VM: $vm_name"
        print_status "INFO" "SSH: ssh -p $SSH_PORT $USERNAME@localhost"
        print_status "INFO" "Senha: $PASSWORD"
        
        # Verificar se o arquivo de imagem existe
        if [[ ! -f "$IMG_FILE" ]]; then
            print_status "ERROR" "Arquivo de imagem da VM não encontrado: $IMG_FILE"
            return 1
        fi
        
        # Verificar se o arquivo de seed existe
        if [[ ! -f "$SEED_FILE" ]]; then
            print_status "WARN" "Arquivo de seed não encontrado, recriando..."
            setup_vm_image
        fi
        
        # Comando base QEMU
        local qemu_cmd=(
            qemu-system-x86_64
            -enable-kvm
            -m "$MEMORY"
            -smp "$CPUS"
            -cpu host
            -drive "file=$IMG_FILE,format=qcow2,if=virtio"
            -drive "file=$SEED_FILE,format=raw,if=virtio"
            -boot order=c
            -device virtio-net-pci,netdev=n0
            -netdev "user,id=n0,hostfwd=tcp::$SSH_PORT-:22"
        )

        # Adicionar redirecionamentos de porta se especificados
        if [[ -n "$PORT_FORWARDS" ]]; then
            IFS=',' read -ra forwards <<< "$PORT_FORWARDS"
            for forward in "${forwards[@]}"; do
                IFS=':' read -r host_port guest_port <<< "$forward"
                qemu_cmd+=(-device "virtio-net-pci,netdev=n${#qemu_cmd[@]}")
                qemu_cmd+=(-netdev "user,id=n${#qemu_cmd[@]},hostfwd=tcp::$host_port-:$guest_port")
            done
        fi

        # Adicionar modo GUI ou console
        if [[ "$GUI_MODE" == true ]]; then
            qemu_cmd+=(-vga virtio -display gtk,gl=on)
        else
            qemu_cmd+=(-nographic -serial mon:stdio)
        fi

        # Adicionar melhorias de performance
        qemu_cmd+=(
            -device virtio-balloon-pci
            -object rng-random,filename=/dev/urandom,id=rng0
            -device virtio-rng-pci,rng=rng0
        )

        print_status "INFO" "Iniciando QEMU..."
        "${qemu_cmd[@]}"
        
        print_status "INFO" "VM $vm_name foi desligada"
    fi
}

# Função para deletar uma VM
delete_vm() {
    local vm_name=$1
    
    print_status "WARN" "Isso deletará permanentemente a VM '$vm_name' e todos os seus dados!"
    read -p "$(print_status "INPUT" "Tem certeza? (s/N): ")" -n 1 -r
    echo
    if [[ $REPLY =~ ^[YySs]$ ]]; then
        if load_vm_config "$vm_name"; then
            rm -f "$IMG_FILE" "$SEED_FILE" "$VM_DIR/$vm_name.conf"
            print_status "SUCCESS" "VM '$vm_name' foi deletada"
        fi
    else
        print_status "INFO" "Deleção cancelada"
    fi
}

# Função para mostrar info da VM
show_vm_info() {
    local vm_name=$1
    
    if load_vm_config "$vm_name"; then
        echo
        print_status "INFO" "Informações da VM: $vm_name"
        echo "=========================================="
        echo "SO: $OS_TYPE"
        echo "Hostname: $HOSTNAME"
        echo "Usuário: $USERNAME"
        echo "Senha: $PASSWORD"
        echo "Porta SSH: $SSH_PORT"
        echo "Memória: $MEMORY MB"
        echo "CPUs: $CPUS"
        echo "Disco: $DISK_SIZE"
        echo "Modo GUI: $GUI_MODE"
        echo "Redirecionamentos de Porta: ${PORT_FORWARDS:-Nenhum}"
        echo "Criada: $CREATED"
        echo "Arquivo de Imagem: $IMG_FILE"
        echo "Arquivo de Seed: $SEED_FILE"
        echo "=========================================="
        echo
        read -p "$(print_status "INPUT" "Pressione Enter para continuar...")"
    fi
}

# Função para verificar se VM está rodando
is_vm_running() {
    local vm_name=$1
    if pgrep -f "qemu-system-x86_64.*$vm_name" >/dev/null; then
        return 0
    else
        return 1
    fi
}

# Função para parar uma VM rodando
stop_vm() {
    local vm_name=$1
    
    if load_vm_config "$vm_name"; then
        if is_vm_running "$vm_name"; then
            print_status "INFO" "Parando VM: $vm_name"
            pkill -f "qemu-system-x86_64.*$IMG_FILE"
            sleep 2
            if is_vm_running "$vm_name"; then
                print_status "WARN" "VM não parou graciosamente, forçando terminação..."
                pkill -9 -f "qemu-system-x86_64.*$IMG_FILE"
            fi
            print_status "SUCCESS" "VM $vm_name parada"
        else
            print_status "INFO" "VM $vm_name não está rodando"
        fi
    fi
}

# Função para editar configuração de VM
edit_vm_config() {
    local vm_name=$1
    
    if load_vm_config "$vm_name"; then
        print_status "INFO" "Editando VM: $vm_name"
        
        while true; do
            echo "O que você gostaria de editar?"
            echo "  1) Hostname"
            echo "  2) Nome de usuário"
            echo "  3) Senha"
            echo "  4) Porta SSH"
            echo "  5) Modo GUI"
            echo "  6) Redirecionamentos de Porta"
            echo "  7) Memória (RAM)"
            echo "  8) Contagem de CPU"
            echo "  9) Tamanho do Disco"
            echo "  0) Voltar ao menu principal"
            
            read -p "$(print_status "INPUT" "Digite sua escolha: ")" edit_choice
            
            case $edit_choice in
                1)
                    while true; do
                        read -p "$(print_status "INPUT" "Digite novo hostname (atual: $HOSTNAME): ")" new_hostname
                        new_hostname="${new_hostname:-$HOSTNAME}"
                        if validate_input "name" "$new_hostname"; then
                            HOSTNAME="$new_hostname"
                            break
                        fi
                    done
                    ;;
                2)
                    while true; do
                        read -p "$(print_status "INPUT" "Digite novo nome de usuário (atual: $USERNAME): ")" new_username
                        new_username="${new_username:-$USERNAME}"
                        if validate_input "username" "$new_username"; then
                            USERNAME="$new_username"
                            break
                        fi
                    done
                    ;;
                3)
                    while true; do
                        read -s -p "$(print_status "INPUT" "Digite nova senha (atual: ****): ")" new_password
                        new_password="${new_password:-$PASSWORD}"
                        echo
                        if [ -n "$new_password" ]; then
                            PASSWORD="$new_password"
                            break
                        else
                            print_status "ERROR" "Senha não pode ser vazia"
                        fi
                    done
                    ;;
                4)
                    while true; do
                        read -p "$(print_status "INPUT" "Digite nova porta SSH (atual: $SSH_PORT): ")" new_ssh_port
                        new_ssh_port="${new_ssh_port:-$SSH_PORT}"
                        if validate_input "port" "$new_ssh_port"; then
                            # Verificar se a porta já está em uso
                            if [ "$new_ssh_port" != "$SSH_PORT" ] && ss -tln 2>/dev/null | grep -q ":$new_ssh_port "; then
                                print_status "ERROR" "Porta $new_ssh_port já está em uso"
                            else
                                SSH_PORT="$new_ssh_port"
                                break
                            fi
                        fi
                    done
                    ;;
                5)
                    while true; do
                        read -p "$(print_status "INPUT" "Ativar modo GUI? (s/n, atual: $GUI_MODE): ")" gui_input
                        gui_input="${gui_input:-}"
                        if [[ "$gui_input" =~ ^[YySs]$ ]]; then 
                            GUI_MODE=true
                            break
                        elif [[ "$gui_input" =~ ^[Nn]$ ]]; then
                            GUI_MODE=false
                            break
                        elif [ -z "$gui_input" ]; then
                            # Manter valor atual se o usuário apenas apertar Enter
                            break
                        else
                            print_status "ERROR" "Por favor, responda s ou n"
                        fi
                    done
                    ;;
                6)
                    read -p "$(print_status "INPUT" "Redirecionamentos de porta adicionais (atual: ${PORT_FORWARDS:-Nenhum}): ")" new_port_forwards
                    PORT_FORWARDS="${new_port_forwards:-$PORT_FORWARDS}"
                    ;;
                7)
                    while true; do
                        read -p "$(print_status "INPUT" "Digite nova memória em MB (atual: $MEMORY): ")" new_memory
                        new_memory="${new_memory:-$MEMORY}"
                        if validate_input "number" "$new_memory"; then
                            MEMORY="$new_memory"
                            break
                        fi
                    done
                    ;;
                8)
                    while true; do
                        read -p "$(print_status "INPUT" "Digite nova contagem de CPU (atual: $CPUS): ")" new_cpus
                        new_cpus="${new_cpus:-$CPUS}"
                        if validate_input "number" "$new_cpus"; then
                            CPUS="$new_cpus"
                            break
                        fi
                    done
                    ;;
                9)
                    while true; do
                        read -p "$(print_status "INPUT" "Digite novo tamanho do disco (atual: $DISK_SIZE): ")" new_disk_size
                        new_disk_size="${new_disk_size:-$DISK_SIZE}"
                        if validate_input "size" "$new_disk_size"; then
                            DISK_SIZE="$new_disk_size"
                            break
                        fi
                    done
                    ;;
                0)
                    return 0
                    ;;
                *)
                    print_status "ERROR" "Seleção inválida"
                    continue
                    ;;
            esac
            
            # Recriar imagem de seed com nova configuração se usuário/senha/hostname mudaram
            if [[ "$edit_choice" -eq 1 || "$edit_choice" -eq 2 || "$edit_choice" -eq 3 ]]; then
                print_status "INFO" "Atualizando configuração do cloud-init..."
                setup_vm_image
            fi
            
            # Salvar configuração
            save_vm_config
            
            read -p "$(print_status "INPUT" "Continuar editando? (s/N): ")" continue_editing
            if [[ ! "$continue_editing" =~ ^[YySs]$ ]]; then
                break
            fi
        done
    fi
}

# Função para redimensionar disco da VM
resize_vm_disk() {
    local vm_name=$1
    
    if load_vm_config "$vm_name"; then
        print_status "INFO" "Tamanho atual do disco: $DISK_SIZE"
        
        while true; do
            read -p "$(print_status "INPUT" "Digite novo tamanho do disco (ex.: 50G): ")" new_disk_size
            if validate_input "size" "$new_disk_size"; then
                if [[ "$new_disk_size" == "$DISK_SIZE" ]]; then
                    print_status "INFO" "Novo tamanho do disco é o mesmo do atual. Nenhuma mudança feita."
                    return 0
                fi
                
                # Verificar se novo tamanho é menor que o atual (não recomendado)
                local current_size_num=${DISK_SIZE%[GgMm]}
                local new_size_num=${new_disk_size%[GgMm]}
                local current_unit=${DISK_SIZE: -1}
                local new_unit=${new_disk_size: -1}
                
                # Converter ambos para MB para comparação
                if [[ "$current_unit" =~ [Gg] ]]; then
                    current_size_num=$((current_size_num * 1024))
                fi
                if [[ "$new_unit" =~ [Gg] ]]; then
                    new_size_num=$((new_size_num * 1024))
                fi
                
                if [[ $new_size_num -lt $current_size_num ]]; then
                    print_status "WARN" "Reduzir o tamanho do disco não é recomendado e pode causar perda de dados!"
                    read -p "$(print_status "INPUT" "Tem certeza que quer continuar? (s/N): ")" confirm_shrink
                    if [[ ! "$confirm_shrink" =~ ^[YySs]$ ]]; then
                        print_status "INFO" "Redimensionamento de disco cancelado."
                        return 0
                    fi
                fi
                
                # Redimensionar o disco
                print_status "INFO" "Redimensionando disco para $new_disk_size..."
                if qemu-img resize "$IMG_FILE" "$new_disk_size"; then
                    DISK_SIZE="$new_disk_size"
                    save_vm_config
                    print_status "SUCCESS" "Disco redimensionado com sucesso para $new_disk_size"
                else
                    print_status "ERROR" "Falha ao redimensionar disco"
                    return 1
                fi
                break
            fi
        done
    fi
}

# Função para mostrar métricas de performance da VM
show_vm_performance() {
    local vm_name=$1
    
    if load_vm_config "$vm_name"; then
        if is_vm_running "$vm_name"; then
            print_status "INFO" "Métricas de performance para VM: $vm_name"
            echo "=========================================="
            
            # Obter PID do processo QEMU
            local qemu_pid=$(pgrep -f "qemu-system-x86_64.*$IMG_FILE")
            if [[ -n "$qemu_pid" ]]; then
                # Mostrar stats do processo
                echo "Estatísticas do Processo QEMU:"
                ps -p "$qemu_pid" -o pid,%cpu,%mem,sz,rss,vsz,cmd --no-headers
                echo
                
                # Mostrar uso de memória
                echo "Uso de Memória:"
                free -h
                echo
                
                # Mostrar uso de disco
                echo "Uso de Disco:"
                df -h "$IMG_FILE" 2>/dev/null || du -h "$IMG_FILE"
            else
                print_status "ERROR" "Não foi possível encontrar processo QEMU para VM $vm_name"
            fi
        else
            print_status "INFO" "VM $vm_name não está rodando"
            echo "Configuração:"
            echo "  Memória: $MEMORY MB"
            echo "  CPUs: $CPUS"
            echo "  Disco: $DISK_SIZE"
        fi
        echo "=========================================="
        read -p "$(print_status "INPUT" "Pressione Enter para continuar...")"
    fi
}

# Função do menu principal
main_menu() {
    while true; do
        display_header
        
        local vms=($(get_vm_list))
        local vm_count=${#vms[@]}
        
        if [ $vm_count -gt 0 ]; then
            print_status "INFO" "Encontradas $vm_count VM(s) existentes:"
            for i in "${!vms[@]}"; do
                local status="Parada"
                if is_vm_running "${vms[$i]}"; then
                    status="Rodando"
                fi
                printf "  %2d) %s (%s)\n" $((i+1)) "${vms[$i]}" "$status"
            done
            echo
        fi
        
        echo "Menu Principal:"
        echo "  1) Criar uma nova VM"
        if [ $vm_count -gt 0 ]; then
            echo "  2) Iniciar uma VM"
            echo "  3) Parar uma VM"
            echo "  4) Mostrar info da VM"
            echo "  5) Editar configuração da VM"
            echo "  6) Deletar uma VM"
            echo "  7) Redimensionar disco da VM"
            echo "  8) Mostrar performance da VM"
        fi
        echo "  0) Sair"
        echo
        
        read -p "$(print_status "INPUT" "Digite sua escolha: ")" choice
        
        case $choice in
            1)
                create_new_vm
                ;;
            2)
                if [ $vm_count -gt 0 ]; then
                    read -p "$(print_status "INPUT" "Digite o número da VM para iniciar: ")" vm_num
                    if [[ "$vm_num" =~ ^[0-9]+$ ]] && [ "$vm_num" -ge 1 ] && [ "$vm_num" -le $vm_count ]; then
                        start_vm "${vms[$((vm_num-1))]}"
                    else
                        print_status "ERROR" "Seleção inválida"
                    fi
                fi
                ;;
            3)
                if [ $vm_count -gt 0 ]; then
                    read -p "$(print_status "INPUT" "Digite o número da VM para parar: ")" vm_num
                    if [[ "$vm_num" =~ ^[0-9]+$ ]] && [ "$vm_num" -ge 1 ] && [ "$vm_num" -le $vm_count ]; then
                        stop_vm "${vms[$((vm_num-1))]}"
                    else
                        print_status "ERROR" "Seleção inválida"
                    fi
                fi
                ;;
            4)
                if [ $vm_count -gt 0 ]; then
                    read -p "$(print_status "INPUT" "Digite o número da VM para mostrar info: ")" vm_num
                    if [[ "$vm_num" =~ ^[0-9]+$ ]] && [ "$vm_num" -ge 1 ] && [ "$vm_num" -le $vm_count ]; then
                        show_vm_info "${vms[$((vm_num-1))]}"
                    else
                        print_status "ERROR" "Seleção inválida"
                    fi
                fi
                ;;
            5)
                if [ $vm_count -gt 0 ]; then
                    read -p "$(print_status "INPUT" "Digite o número da VM para editar: ")" vm_num
                    if [[ "$vm_num" =~ ^[0-9]+$ ]] && [ "$vm_num" -ge 1 ] && [ "$vm_num" -le $vm_count ]; then
                        edit_vm_config "${vms[$((vm_num-1))]}"
                    else
                        print_status "ERROR" "Seleção inválida"
                    fi
                fi
                ;;
            6)
                if [ $vm_count -gt 0 ]; then
                    read -p "$(print_status "INPUT" "Digite o número da VM para deletar: ")" vm_num
                    if [[ "$vm_num" =~ ^[0-9]+$ ]] && [ "$vm_num" -ge 1 ] && [ "$vm_num" -le $vm_count ]; then
                        delete_vm "${vms[$((vm_num-1))]}"
                    else
                        print_status "ERROR" "Seleção inválida"
                    fi
                fi
                ;;
            7)
                if [ $vm_count -gt 0 ]; then
                    read -p "$(print_status "INPUT" "Digite o número da VM para redimensionar disco: ")" vm_num
                    if [[ "$vm_num" =~ ^[0-9]+$ ]] && [ "$vm_num" -ge 1 ] && [ "$vm_num" -le $vm_count ]; then
                        resize_vm_disk "${vms[$((vm_num-1))]}"
                    else
                        print_status "ERROR" "Seleção inválida"
                    fi
                fi
                ;;
            8)
                if [ $vm_count -gt 0 ]; then
                    read -p "$(print_status "INPUT" "Digite o número da VM para mostrar performance: ")" vm_num
                    if [[ "$vm_num" =~ ^[0-9]+$ ]] && [ "$vm_num" -ge 1 ] && [ "$vm_num" -le $vm_count ]; then
                        show_vm_performance "${vms[$((vm_num-1))]}"
                    else
                        print_status "ERROR" "Seleção inválida"
                    fi
                fi
                ;;
            0)
                print_status "INFO" "Até logo!"
                exit 0
                ;;
            *)
                print_status "ERROR" "Opção inválida"
                ;;
        esac
        
        read -p "$(print_status "INPUT" "Pressione Enter para continuar...")"
    done
}

# Definir trap para limpar na saída
trap cleanup EXIT

# Verificar dependências
check_dependencies

# Inicializar caminhos
VM_DIR="${VM_DIR:-$HOME/vms}"
mkdir -p "$VM_DIR"

# Lista de SOs suportados
declare -A OS_OPTIONS=(
    ["Ubuntu 22.04"]="ubuntu|jammy|https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img|ubuntu22|ubuntu|ubuntu"
    ["Ubuntu 24.04"]="ubuntu|noble|https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img|ubuntu24|ubuntu|ubuntu"
    ["Debian 11"]="debian|bullseye|https://cloud.debian.org/images/cloud/bullseye/latest/debian-11-generic-amd64.qcow2|debian11|debian|debian"
    ["Debian 12"]="debian|bookworm|https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2|debian12|debian|debian"
    ["Fedora 40"]="fedora|40|https://download.fedoraproject.org/pub/fedora/linux/releases/40/Cloud/x86_64/images/Fedora-Cloud-Base-40-1.14.x86_64.qcow2|fedora40|fedora|fedora"
    ["CentOS Stream 9"]="centos|stream9|https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2|centos9|centos|centos"
    ["AlmaLinux 9"]="almalinux|9|https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2|almalinux9|alma|alma"
    ["Rocky Linux 9"]="rockylinux|9|https://download.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud.latest.x86_64.qcow2|rocky9|rocky|rocky"
)

# Iniciar o menu principal
main_menu
