# 🚀 Guia Completo de Configuração de VM no Google IDX (2025)

## 🖥️ 1. Instalando a VM no Google IDX

**Site oficial do Google IDX:**  
[https://idx.google.com/](https://idx.google.com/)

Passo a passo:

1. Acesse o link acima e faça login com sua conta Google (é totalmente grátis).
2. Clique em **“New workspace”** (Novo espaço de trabalho).
3. No campo **“Repository URL”**, cole exatamente este link (⚠️ NÃO mude o nome do repositório):

   **URL do Repositório:**  
   [https://github.com/jishnudiscord14-droid/vps123](https://github.com/jishnudiscord14-droid/vps123)

4. Clique em **Create** e aguarde o workspace carregar (pode levar 1–2 minutos).

### ▶️ Comando para instalar e gerenciar a VM (totalmente em português)

No terminal que abre automaticamente, cole e execute:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/jzvoorhees/vpstest/main/vps.sh)
```
Pronto! O menu agora está 100% em português brasileiro e super fácil de usar.

🐦 2. (Opcional) Instalando o Painel Pterodactyl na VM
Se quiser transformar sua VM em um painel de hospedagem de servidores de jogos (Minecraft, Rust, etc.), execute este comando dentro da VM já rodando:

```bash
bash <(curl -s https://ptero.jishnu.fun)
```
☁️ 3. (Opcional) Configurar domínio + SSL grátis com Cloudflare
Quer acessar sua VM ou painel Pterodactyl por um domínio bonito seusite.com com HTTPS?

Crie uma conta gratuita no Cloudflare:
https://dash.cloudflare.com/

Adicione seu domínio (pode comprar barato ou usar subdomínios grátis tipo .tk, .ml, etc.).
Aponte os Nameservers para os do Cloudflare.

Crie registros A ou CNAME apontando para o IP público (se estiver usando túnel) ou use o Cloudflare Tunnel (Zero Trust → totalmente grátis).
🎉 Tudo pronto e funcionando 24/7!

Agora você tem:

Uma VM Linux poderosa rodando dentro do Google IDX (grátis e online 24 horas)
Gerenciador de VMs com menu em português brasileiro
Pode rodar bots do Telegram/Discord, sites, servidores de jogos, VPN, etc.
Recursos generosos: até 16 GB RAM + 8 vCPUs + 100 GB+ de disco
Truque para nunca cair (funciona até hoje em dezembro de 2025)
Deixe a aba do Google IDX aberta no navegador (pode ser no celular também)
Ou instale a extensão “Auto Refresh Plus” e configure para recarregar a página a cada 10 minutos
Créditos e Agradecimentos
Esse método incrível só existe graças a esses gênios:

HopingBoiyz
Jishnu
NotGamerPie
E agora com menu traduzido para português por aqui ❤️
