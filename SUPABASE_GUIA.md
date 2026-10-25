# Guia de Integração Supabase - SIA (AFPJV)

Este guia explica como conectar a aplicação **SIA (Sistema de Integração Académica)** da **Associação de Formação Profissional Jovens Valentes** ao seu próprio projeto no **Supabase** e como executar as migrações geradas.

---

## 1. Ficheiros de Migração Gerados

Os scripts SQL com a estrutura completa da base de dados (tabelas, chaves estrangeiras, enums, triggers, funções RPC, RLS e dados iniciais) estão disponíveis em:

1. **`/supabase/migrations/20261025000000_init_sia.sql`** (Padrão Supabase CLI)
2. **`/supabase_schema_and_migrations.sql`** (Ficheiro unificado para execução direta no navegador)

---

## 2. Como Executar as Migrações no Supabase

### Opção A: Pelo Painel Web do Supabase (Mais Rápido e Fácil)

1. Aceda ao [Supabase Dashboard](https://supabase.com/dashboard) e abra o seu projeto (ou crie um novo projeto gratuito).
2. No menu lateral esquerdo, clique no ícone **SQL Editor** (`>_`).
3. Clique em **+ New query**.
4. Abra o ficheiro `supabase_schema_and_migrations.sql` deste projeto, copie todo o seu conteúdo e cole no editor do Supabase.
5. Clique no botão verde **Run** (Executar) no canto inferior direito.
6. Pronto! Todas as **17 tabelas**, **políticas de segurança RLS**, **gatilhos de utilizadores**, **funções RPC** (`finalize_application` e `confirm_payment`), o **bucket de documentos** (`application-documents`) e os **centros e cursos iniciais da AFPJV** foram criados.

---

### Opção B: Pelo Supabase CLI (Linha de Comandos)

Se já tiver o Supabase CLI instalado na sua máquina:

```bash
# Vincular ao seu projeto Supabase
supabase link --project-ref seu-project-ref

# Aplicar as migrações
supabase db push
```

---

## 3. Como Obter as Credenciais no Supabase

1. No painel do seu projeto no Supabase, clique em **Project Settings** (ícone de engrenagem no menu lateral).
2. Selecione **API** (sob a secção *Configuration*).
3. Copie os seguintes dados:
   - **Project URL** (ex: `https://xyzcompany.supabase.co`)
   - **Project API keys** -> Chave **`anon` `public`** (ex: `eyJhbGciOi...`)

> ⚠️ **Atenção de Segurança:** Nunca utilize a chave `service_role` (secret) no cliente web. Apenas a chave pública `anon` deve ser utilizada no frontend. As políticas de segurança (RLS) protegem os dados no servidor.

---

## 4. Como Conectar o SIA ao Supabase

Você pode conectar o SIA ao Supabase de duas formas:

### Método 1: Diretamente pela Interface do SIA (Recomendado)
1. Abra a aplicação SIA no navegador.
2. Inicie sessão e vá ao menu lateral -> **Configurações**.
3. Clique na aba **Integrações**.
4. No cartão **Conexão Supabase**, cole o seu **Project URL** e a sua **Anon Key**.
5. Clique em **Guardar e Conectar ao Supabase**.
6. A aplicação testará a conexão imediatamente e mudará o estado para **Conectado**.

### Método 2: Por Variáveis de Ambiente (.env)
No ficheiro `.env` da aplicação, adicione:
```env
VITE_SUPABASE_URL="https://seu-projeto.supabase.co"
VITE_SUPABASE_ANON_KEY="sua-chave-anon-publica-aqui"
```

---

## 5. Estrutura das Tabelas Criadas

| Tabela | Descrição |
|---|---|
| `centers` | Centros de formação da instituição (Maputo, Matola, Xai-Xai, etc.) |
| `courses` | Cursos publicados, durações, taxas de inscrição e propinas |
| `applications` | Pré-inscrições e candidaturas submetidas online |
| `application_documents` | Metadados dos ficheiros (BI, certificados, fotos tipo passe) |
| `profiles` | Perfis vinculados ao `auth.users` (`admin_principal`, `admin_centro`, `formador`, `aluno`) |
| `students` | Estudantes matriculados com código gerado (ex: `STU-2026-XXXX`) |
| `enrollments` | Matrículas ativas dos estudantes nos cursos |
| `subjects` | Disciplinas curriculares e carga horária |
| `classes` | Turmas, turnos e salas |
| `attendance` | Registo de chamadas de presenças e faltas |
| `assessments` | Avaliações e exames |
| `grades` | Pautas de notas de 0 a 20 e publicação |
| `fees` | Tabela de emolumentos e taxas |
| `payments` | Registo e validação financeira de pagamentos (M-Pesa, Numerário, e-Mola, Banco) |
| `notifications` | Avisos e comunicados da instituição |
| `audit_logs` | Trilha de auditoria de operações administrativas |
| `institution_settings` | Identidade visual, logotipo, contactos e regras de idade |

---

## 6. Funções Especiais (RPC)

- **`public.finalize_application(p_application_id uuid)`**: Valida a candidatura, gera o código de estudante único, cria a matrícula e atualiza o estado para matriculado.
- **`public.confirm_payment(p_payment_id uuid)`**: Valida permissões de administrador, gera número oficial de recibo (`REC-YYYYMM-XXXXX`) e confirma o pagamento.
- **`public.handle_new_user()`**: Trigger automático que cria o perfil de utilizador em `public.profiles` sempre que uma conta é criada no Supabase Auth.
