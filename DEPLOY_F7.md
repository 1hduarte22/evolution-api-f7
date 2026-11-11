# Evolution API para o F7 CRM — publicação grátis

A Evolution API conecta o WhatsApp ao CRM pelo **QR code** (conexão não oficial, via WhatsApp Web).
Ela precisa ficar **ligada o tempo todo**: se desligar, o WhatsApp para de chegar no CRM.

Há duas opções sem custo. Comece pela A; se notar quedas frequentes, migre para a B.

| | A. Render Free | B. Oracle Cloud Always Free |
|---|---|---|
| Custo | R$ 0 | R$ 0 (pede cartão só para verificação) |
| Dificuldade | Fácil (blueprint) | Média (uma VM com Docker) |
| Estabilidade | Boa com o "ping" do CRM; o Render pode reiniciar serviços grátis | Muito boa (máquina sempre ligada) |

Nas duas, o **banco da Evolution fica no próprio Supabase do CRM**, num schema separado
chamado `evolution` (não mistura com as tabelas do CRM e não custa nada). É lá que fica a
sessão do WhatsApp: reinícios e deploys **não** pedem para ler o QR code de novo.

> ⚠️ Conexão não oficial: o WhatsApp pode bloquear números que mandam mensagem em massa para
> quem não autorizou. Use um número dedicado à empresa, mande só para quem autorizou e mantenha
> os limites baixos (o CRM já aplica limite diário, intervalo e horário comercial).

---

## 1. String de conexão do Supabase (para as duas opções)

1. Supabase → **Project Settings → Database → Connection string**.
2. Escolha **Session pooler** (porta **5432**). Não use a "Direct connection" (o Render não fala IPv6)
   nem a "Transaction pooler" (porta 6543, não funciona com as migrations da Evolution).
3. Troque `[YOUR-PASSWORD]` pela senha do banco e acrescente **`?schema=evolution`** no fim:

```
postgresql://postgres.SEU_REF:SENHA@aws-0-sa-east-1.pooler.supabase.com:5432/postgres?schema=evolution
```

## 2A. Render (grátis)

1. Entre em <https://render.com> com o GitHub → **New → Blueprint** → escolha o repositório
   `evolution-api-f7`. O Render lê o `render.yaml` deste repositório.
2. Ele pede dois valores:
   - `DATABASE_CONNECTION_URI`: a string do passo 1.
   - `SERVER_URL`: deixe `https://f7-evolution.onrender.com` (ajuste depois se o Render der outro endereço).
3. **Apply**. O primeiro deploy leva uns 5 minutos.
4. Em **f7-evolution → Environment**, copie o valor de `AUTHENTICATION_API_KEY` (foi gerado sozinho).

**Para não dormir:** o plano Free desliga após 15 minutos sem acesso. O CRM já tem um agendador
que acessa a Evolution a cada 10 minutos — basta informar o endereço no Supabase (passo 4).
Um serviço ligado o mês inteiro usa ~730 das 750 horas grátis do Render, e essas horas são
**divididas entre todos os serviços Free da conta**. Se você já tem outros serviços grátis no Render
(ex.: area45-api, sprint-battle), eles vão parar no fim do mês — nesse caso use a opção B.

## 2B. Oracle Cloud Always Free (alternativa estável)

1. Crie a conta em <https://www.oracle.com/cloud/free/> e uma VM **Ampere A1** (Always Free) com Ubuntu.
2. Libere as portas 80 e 443 (Security List da VCN e `sudo iptables` / `ufw` na VM).
3. Crie um domínio grátis no <https://www.duckdns.org> apontando para o IP da VM.
4. Na VM:

```bash
sudo apt update && sudo apt install -y docker.io docker-compose-v2 git
git clone https://github.com/1hduarte22/evolution-api-f7 && cd evolution-api-f7
cp .env.f7.example .env.f7 && nano .env.f7     # domínio, chave (openssl rand -hex 24) e string do Supabase
sudo docker compose -f docker-compose.f7.yaml --env-file .env.f7 up -d
```

O Caddy emite o HTTPS automaticamente.

## 3. Ativar a licença (uma vez)

A partir da versão 2.4 a Evolution pede uma ativação gratuita antes de funcionar.

1. Abra `https://SEU-ENDERECO/manager` e entre com a `AUTHENTICATION_API_KEY`.
2. O painel leva para o cadastro da Evolution Foundation; preencha e volte.
3. Pronto: a ativação fica salva no banco e vale para os próximos reinícios.

## 4. Ligar ao CRM

1. Supabase → **Edge Functions → Secrets**:
   - `EVOLUTION_API_URL` = `https://f7-evolution.onrender.com` (ou o seu domínio)
   - `EVOLUTION_API_KEY` = a `AUTHENTICATION_API_KEY`
   - `ANTHROPIC_API_KEY` = só se for usar os agentes de IA
2. Supabase → **SQL Editor** (agendador do "ping" e endereço das funções):

```sql
insert into private.app_config (key, value) values
  ('evolution_url', 'https://f7-evolution.onrender.com'),
  ('functions_url', 'https://SEU-PROJETO.supabase.co/functions/v1')
on conflict (key) do update set value = excluded.value;
```

3. No CRM: **Configurações → Canais → Novo canal → WhatsApp → Conectar com QR code**.
   O CRM cria a instância na Evolution, registra o webhook e mostra o QR code.

## Problemas comuns

| Sintoma | O que fazer |
|---|---|
| "A Evolution API ainda não foi ativada (licença)" | Faça o passo 3 |
| "Evolution API fora do ar" na tela de Canais | Veja os logs no Render; confira `DATABASE_CONNECTION_URI` (Session pooler, porta 5432, `?schema=evolution`) |
| O QR code não aparece | Clique em "Gerar novo QR code"; no Render Free a primeira chamada pode levar até 1 minuto (acordando) |
| Canal cai para "Desconectado" | Reconecte pelo QR code. Se acontecer sempre, migre para a opção B |
