# Migração para Firebase Hosting

Guia passo a passo para migrar o Music Map de GitHub Pages para Firebase Hosting.

---

## 1. Arquivos criados

Os seguintes arquivos foram adicionados/alterados:

- **`firebase.json`** – Configuração do Hosting e regras do Database
- **`.firebaserc`** – ID do projeto Firebase
- **`.github/workflows/deploy.yml`** – Deploy via GitHub Actions
- **`base-href`** – Alterado de `/musicalmap/` para `/` (app na raiz do domínio)

---

## 2. Configurar token do Firebase no GitHub

Para o deploy automático funcionar, é necessário um token de CI:

1. Instale o Firebase CLI (se ainda não tiver):
   ```bash
   npm install -g firebase-tools
   ```

2. Faça login e gere o token:
   ```bash
   firebase login:ci
   ```
   Siga o fluxo no navegador e copie o token gerado.

3. Crie o secret no GitHub:
   - Repositório → **Settings** → **Secrets and variables** → **Actions**
   - **New repository secret**
   - Nome: `FIREBASE_TOKEN`
   - Valor: cole o token obtido no passo anterior

---

## 3. Atualizar OAuth do Google

Com Firebase Hosting, o app passa a rodar em um domínio diferente. Ajuste o OAuth:

1. Acesse [Google Cloud Console](https://console.cloud.google.com) → Credenciais
2. Edite o **Cliente OAuth 2.0** (Web application)
3. Em **Origens JavaScript autorizadas**, adicione:
   - `https://palacepulse-2262c.web.app`
   - `https://palacepulse-2262c.firebaseapp.com`
4. Em **URIs de redirecionamento autorizados**, adicione:
   - `https://palacepulse-2262c.web.app/`
   - `https://palacepulse-2262c.firebaseapp.com/`
5. Salve as alterações

---

## 4. Testar o deploy localmente

Antes de usar o CI/CD:

```bash
# Build do app
flutter build web --base-href / --release

# Deploy manual (requer firebase login)
firebase deploy
```

---

## 5. Ativar Hosting no Firebase (se ainda não estiver)

1. Acesse o [Firebase Console](https://console.firebase.google.com)
2. Selecione o projeto **palacepulse-2262c**
3. Vá em **Build** → **Hosting**
4. Clique em **Get started** se o Hosting ainda não estiver ativado

---

## 6. Fazer o deploy

Após configurar o secret `FIREBASE_TOKEN`:

1. Dê push na branch `main`:
   ```bash
   git add .
   git commit -m "chore: migrar deploy para Firebase Hosting"
   git push origin main
   ```

2. O workflow será executado em **Actions** e fará o deploy automaticamente

3. O app ficará disponível em:
   - **https://palacepulse-2262c.web.app**
   - **https://palacepulse-2262c.firebaseapp.com**

---

## 7. Domínio customizado (opcional)

Para usar um domínio próprio (ex: `musicalmap.com.br`):

1. Firebase Console → Hosting → **Add custom domain**
2. Siga as instruções para configurar DNS
3. Adicione o domínio em **Origens JavaScript** e **URIs de redirecionamento** no Google Cloud Console

---

## 8. Desativar GitHub Pages

Depois de validar o app no Firebase Hosting:

1. Repositório → **Settings** → **Pages**
2. Em **Source**, escolha **Deploy from a branch**
3. Selecione a opção **None** para desativar o GitHub Pages
