-- ==============================================================================
-- SIA - Sistema de Integração Académica
-- Associação de Formação Profissional Jovens Valentes (AFPJV)
-- Script de Migração Inicial do Supabase (PostgreSQL 15+)
-- ==============================================================================
-- COMO UTILIZAR NO SUPABASE:
-- 1. Aceda ao painel do seu projecto no Supabase (https://supabase.com/dashboard)
-- 2. No menu lateral, clique em "SQL Editor"
-- 3. Crie uma "New query", copie todo o conteúdo deste ficheiro e cole lá
-- 4. Clique em "Run" para executar a migração completa!
-- 5. No menu "Settings" -> "API", copie o URL e a chave 'anon' (public) e adicione-os
--    no ecrã de Configurações -> Integrações da aplicação ou no ficheiro .env.
-- ==============================================================================

-- 1. Habilitar extensões necessárias
create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";

-- ==============================================================================
-- 2. TABELAS PRINCIPAIS
-- ==============================================================================

-- 2.1. Centros de Formação
create table if not exists public.centers (
    id uuid primary key default gen_random_uuid(),
    name text not null,
    location text,
    phone text,
    email text,
    active boolean not null default true,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

-- 2.2. Cursos
create table if not exists public.courses (
    id uuid primary key default gen_random_uuid(),
    name text not null,
    center_id uuid references public.centers(id) on delete cascade,
    registration_fee numeric(12,2) not null default 0.00,
    monthly_fee numeric(12,2) not null default 0.00,
    duration text,
    active boolean not null default true,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

-- 2.3. Pré-inscrições (Candidaturas)
create table if not exists public.applications (
    id uuid primary key default gen_random_uuid(),
    reference text unique not null,
    full_name text not null,
    birth_date date not null,
    sex text check (sex in ('Masculino', 'Feminino', 'Prefiro não indicar', null)),
    nationality text default 'Moçambicana',
    id_type text not null,
    id_number text not null,
    phone text not null,
    whatsapp text,
    email text,
    address text,
    education_level text not null,
    last_grade text,
    course_id uuid references public.courses(id),
    center_id uuid references public.centers(id),
    schedule text,
    status text not null default 'submitted' check (
        status in (
            'submitted',
            'under_review',
            'documents_review',
            'awaiting_center',
            'awaiting_payment',
            'partially_paid',
            'paid',
            'enrolled',
            'rejected',
            'cancelled'
        )
    ),
    status_reason text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

-- 2.4. Documentos da Pré-inscrição
create table if not exists public.application_documents (
    id uuid primary key default gen_random_uuid(),
    application_id uuid not null references public.applications(id) on delete cascade,
    kind text not null check (kind in ('id_document', 'certificate', 'photo', 'other')),
    storage_path text not null,
    file_name text not null,
    created_at timestamptz not null default now()
);

-- 2.5. Perfis de Utilizadores (vinculados a auth.users)
create table if not exists public.profiles (
    id uuid primary key references auth.users(id) on delete cascade,
    full_name text,
    role text not null default 'aluno' check (
        role in ('admin_principal', 'admin_centro', 'formador', 'aluno')
    ),
    center_id uuid references public.centers(id),
    phone text,
    active boolean not null default true,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

-- 2.6. Estudantes (Matrículas Concluídas)
create table if not exists public.students (
    id uuid primary key default gen_random_uuid(),
    student_code text unique not null,
    application_id uuid references public.applications(id),
    user_id uuid references auth.users(id) on delete set null,
    full_name text not null,
    birth_date date,
    sex text,
    nationality text default 'Moçambicana',
    id_type text,
    id_number text,
    phone text,
    email text,
    address text,
    course_id uuid references public.courses(id),
    center_id uuid references public.centers(id),
    status text not null default 'active' check (
        status in ('active', 'inactive', 'completed', 'suspended', 'dropped')
    ),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

-- 2.7. Inscrições em Cursos (Histórico / Matrículas)
create table if not exists public.enrollments (
    id uuid primary key default gen_random_uuid(),
    student_id uuid not null references public.students(id) on delete cascade,
    course_id uuid not null references public.courses(id),
    center_id uuid not null references public.centers(id),
    status text not null default 'enrolled',
    enrolled_at timestamptz not null default now()
);

-- 2.8. Disciplinas
create table if not exists public.subjects (
    id uuid primary key default gen_random_uuid(),
    name text not null,
    code text,
    course_id uuid references public.courses(id),
    workload_hours integer,
    created_at timestamptz not null default now()
);

-- 2.9. Turmas
create table if not exists public.classes (
    id uuid primary key default gen_random_uuid(),
    name text not null,
    course_id uuid references public.courses(id),
    center_id uuid references public.centers(id),
    shift text check (shift in ('Manhã', 'Tarde', 'Noite', 'Flexível', null)),
    active boolean not null default true,
    created_at timestamptz not null default now()
);

-- 2.10. Presenças (Chamadas de Assiduidade)
create table if not exists public.attendance (
    id uuid primary key default gen_random_uuid(),
    class_id uuid not null references public.classes(id),
    student_id uuid not null references public.students(id) on delete cascade,
    subject_id uuid references public.subjects(id),
    attendance_date date not null,
    status text not null check (status in ('present', 'absent', 'late', 'justified')),
    marked_by uuid references auth.users(id),
    created_at timestamptz not null default now()
);

-- 2.11. Avaliações
create table if not exists public.assessments (
    id uuid primary key default gen_random_uuid(),
    name text not null,
    subject_id uuid references public.subjects(id),
    class_id uuid references public.classes(id),
    date date,
    max_score numeric(4,1) default 20.0,
    created_at timestamptz not null default now()
);

-- 2.12. Notas
create table if not exists public.grades (
    id uuid primary key default gen_random_uuid(),
    student_id uuid not null references public.students(id) on delete cascade,
    assessment_id uuid not null references public.assessments(id),
    subject_id uuid not null references public.subjects(id),
    score numeric(4,1) not null check (score >= 0 and score <= 20),
    published boolean not null default false,
    recorded_by uuid references auth.users(id),
    created_at timestamptz not null default now()
);

-- 2.13. Taxas e Emolumentos
create table if not exists public.fees (
    id uuid primary key default gen_random_uuid(),
    course_id uuid references public.courses(id),
    name text not null,
    amount numeric(12,2) not null,
    due_day integer check (due_day between 1 and 31),
    created_at timestamptz not null default now()
);

-- 2.14. Pagamentos
create table if not exists public.payments (
    id uuid primary key default gen_random_uuid(),
    student_id uuid not null references public.students(id) on delete cascade,
    amount numeric(12,2) not null check (amount > 0),
    method text not null check (method in ('Numerário', 'M-Pesa', 'e-Mola', 'Transferência bancária', 'Outro')),
    reference text,
    receipt_number text,
    status text not null default 'pending' check (status in ('pending', 'confirmed', 'rejected')),
    recorded_by uuid references auth.users(id),
    confirmed_by uuid references auth.users(id),
    created_at timestamptz not null default now()
);

-- 2.15. Notificações do Sistema
create table if not exists public.notifications (
    id uuid primary key default gen_random_uuid(),
    user_id uuid references auth.users(id) on delete cascade,
    title text not null,
    message text not null,
    read_at timestamptz,
    created_at timestamptz not null default now()
);

-- 2.16. Auditoria de Operações
create table if not exists public.audit_logs (
    id uuid primary key default gen_random_uuid(),
    actor_id uuid references auth.users(id) on delete set null,
    action text not null,
    entity_table text not null,
    entity_id text,
    details jsonb,
    created_at timestamptz not null default now()
);

-- 2.17. Configurações Institucionais
create table if not exists public.institution_settings (
    id text primary key default 'default',
    institution_name text not null default 'Associação de Formação Profissional Jovens Valentes',
    facebook_url text default 'https://www.facebook.com/profile.php?id=61575852942153',
    whatsapp_number text default '',
    logo_url text,
    banner_url text,
    minimum_age integer not null default 17,
    maximum_age integer not null default 45,
    updated_at timestamptz not null default now()
);

-- ==============================================================================
-- 3. FUNÇÕES E TRIGGERS
-- ==============================================================================

-- 3.1. Criação automática de perfil ao registar novo utilizador no Auth
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    insert into public.profiles (id, full_name, role)
    values (
        new.id,
        coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1)),
        coalesce(new.raw_user_meta_data->>'role', 'aluno')
    )
    on conflict (id) do update set
        full_name = coalesce(excluded.full_name, profiles.full_name);
    return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
    after insert on auth.users
    for each row execute function public.handle_new_user();

-- 3.2. RPC para Finalizar Matrícula a partir de uma Pré-inscrição
create or replace function public.finalize_application(p_application_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_app public.applications%rowtype;
    v_student_code text;
    v_student_id uuid;
    v_student_count integer;
begin
    -- Verificar candidatura
    select * into v_app from public.applications where id = p_application_id;
    if not found then
        raise exception 'Candidatura não encontrada.';
    end if;

    -- Verificar se já existe estudante vinculado
    select count(*) into v_student_count from public.students where application_id = p_application_id;
    if v_student_count > 0 then
        raise exception 'Esta candidatura já possui estudante matriculado.';
    end if;

    -- Gerar código do estudante (ex: STU-2026-0001)
    v_student_code := 'STU-' || to_char(now(), 'YYYY') || '-' || lpad((floor(random() * 9000 + 1000))::text, 4, '0');

    -- Inserir estudante
    insert into public.students (
        student_code,
        application_id,
        full_name,
        birth_date,
        sex,
        nationality,
        id_type,
        id_number,
        phone,
        email,
        address,
        course_id,
        center_id,
        status
    ) values (
        v_student_code,
        v_app.id,
        v_app.full_name,
        v_app.birth_date,
        v_app.sex,
        v_app.nationality,
        v_app.id_type,
        v_app.id_number,
        v_app.phone,
        v_app.email,
        v_app.address,
        v_app.course_id,
        v_app.center_id,
        'active'
    ) returning id into v_student_id;

    -- Criar matrícula no curso
    if v_app.course_id is not null and v_app.center_id is not null then
        insert into public.enrollments (student_id, course_id, center_id, status)
        values (v_student_id, v_app.course_id, v_app.center_id, 'enrolled');
    end if;

    -- Actualizar estado da pré-inscrição
    update public.applications
    set status = 'enrolled',
        updated_at = now()
    where id = p_application_id;

    -- Log de auditoria
    insert into public.audit_logs (actor_id, action, entity_table, entity_id, details)
    values (
        auth.uid(),
        'application_finalized',
        'applications',
        p_application_id::text,
        jsonb_build_object('student_id', v_student_id, 'student_code', v_student_code)
    );

    return jsonb_build_object(
        'student_id', v_student_id,
        'student_code', v_student_code,
        'full_name', v_app.full_name
    );
end;
$$;

-- 3.3. RPC para Validar/Confirmar Pagamento
create or replace function public.confirm_payment(p_payment_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_receipt text;
    v_payment public.payments%rowtype;
    v_caller_role text;
begin
    -- Verificar permissão do chamador
    select role into v_caller_role from public.profiles where id = auth.uid();
    if v_caller_role is null or v_caller_role not in ('admin_principal', 'admin_centro') then
        raise exception 'Não tem autorização para confirmar pagamentos.';
    end if;

    select * into v_payment from public.payments where id = p_payment_id;
    if not found then
        raise exception 'Pagamento não encontrado.';
    end if;

    -- Gerar número de recibo
    v_receipt := 'REC-' || to_char(now(), 'YYYYMM') || '-' || lpad((floor(random() * 90000 + 10000))::text, 5, '0');

    update public.payments
    set status = 'confirmed',
        receipt_number = v_receipt,
        confirmed_by = auth.uid()
    where id = p_payment_id;

    -- Auditoria
    insert into public.audit_logs (actor_id, action, entity_table, entity_id, details)
    values (
        auth.uid(),
        'payment_confirmed',
        'payments',
        p_payment_id::text,
        jsonb_build_object('receipt_number', v_receipt, 'amount', v_payment.amount)
    );

    return jsonb_build_object(
        'payment_id', p_payment_id,
        'receipt_number', v_receipt,
        'status', 'confirmed'
    );
end;
$$;

-- ==============================================================================
-- 4. POLÍTICAS DE SEGURANÇA (ROW LEVEL SECURITY - RLS)
-- ==============================================================================

alter table public.centers enable row level security;
alter table public.courses enable row level security;
alter table public.applications enable row level security;
alter table public.application_documents enable row level security;
alter table public.profiles enable row level security;
alter table public.students enable row level security;
alter table public.enrollments enable row level security;
alter table public.subjects enable row level security;
alter table public.classes enable row level security;
alter table public.attendance enable row level security;
alter table public.assessments enable row level security;
alter table public.grades enable row level security;
alter table public.fees enable row level security;
alter table public.payments enable row level security;
alter table public.notifications enable row level security;
alter table public.audit_logs enable row level security;
alter table public.institution_settings enable row level security;

-- 4.1. Centros e Cursos (Leitura pública para o catálogo, gestão por admins)
create policy "Centros visíveis para todos" on public.centers for select using (true);
create policy "Admins gerem centros" on public.centers for all using (
    exists (select 1 from public.profiles where id = auth.uid() and role = 'admin_principal')
);

create policy "Cursos visíveis para todos" on public.courses for select using (true);
create policy "Admins gerem cursos" on public.courses for all using (
    exists (select 1 from public.profiles where id = auth.uid() and role in ('admin_principal', 'admin_centro'))
);

-- 4.2. Pré-inscrições (Qualquer pessoa pode submeter; apenas equipa acede)
create policy "Qualquer pessoa pode submeter candidatura" on public.applications
    for insert with check (true);

create policy "Equipa autorizada consulta candidaturas" on public.applications
    for select using (
        exists (select 1 from public.profiles where id = auth.uid() and role in ('admin_principal', 'admin_centro'))
    );

create policy "Equipa autorizada actualiza candidaturas" on public.applications
    for update using (
        exists (select 1 from public.profiles where id = auth.uid() and role in ('admin_principal', 'admin_centro'))
    );

create policy "Qualquer pessoa insere documentos de candidatura" on public.application_documents
    for insert with check (true);

create policy "Equipa acede a documentos de candidatura" on public.application_documents
    for select using (
        exists (select 1 from public.profiles where id = auth.uid() and role in ('admin_principal', 'admin_centro'))
    );

-- 4.3. Perfis
create policy "Utilizadores lêem perfis próprios ou admins lêem todos" on public.profiles
    for select using (
        auth.uid() = id or exists (select 1 from public.profiles where id = auth.uid() and role in ('admin_principal', 'admin_centro'))
    );

create policy "Admins actualizam perfis" on public.profiles
    for update using (
        auth.uid() = id or exists (select 1 from public.profiles where id = auth.uid() and role = 'admin_principal')
    );

-- 4.4. Estudantes e Matrículas
create policy "Equipa acede a estudantes" on public.students
    for all using (
        exists (select 1 from public.profiles where id = auth.uid() and role in ('admin_principal', 'admin_centro', 'formador'))
        or user_id = auth.uid()
    );

create policy "Equipa acede a matrículas" on public.enrollments
    for all using (
        exists (select 1 from public.profiles where id = auth.uid() and role in ('admin_principal', 'admin_centro'))
    );

-- 4.5. Turmas e Disciplinas
create policy "Acesso a turmas" on public.classes for all using (
    exists (select 1 from public.profiles where id = auth.uid() and role in ('admin_principal', 'admin_centro', 'formador'))
);
create policy "Acesso a disciplinas" on public.subjects for all using (true);

-- 4.6. Presenças
create policy "Formadores e admins gerem presenças" on public.attendance
    for all using (
        exists (select 1 from public.profiles where id = auth.uid() and role in ('admin_principal', 'admin_centro', 'formador'))
    );
create policy "Estudantes consultam as suas presenças" on public.attendance
    for select using (
        exists (select 1 from public.students where id = attendance.student_id and user_id = auth.uid())
    );

-- 4.7. Avaliações e Notas
create policy "Acesso a avaliações" on public.assessments for all using (
    exists (select 1 from public.profiles where id = auth.uid() and role in ('admin_principal', 'admin_centro', 'formador'))
);

create policy "Equipa gere notas" on public.grades for all using (
    exists (select 1 from public.profiles where id = auth.uid() and role in ('admin_principal', 'admin_centro', 'formador'))
);
create policy "Estudantes consultam notas publicadas" on public.grades for select using (
    published = true and exists (select 1 from public.students where id = grades.student_id and user_id = auth.uid())
);

-- 4.8. Pagamentos e Finanças
create policy "Equipa gere pagamentos" on public.payments for all using (
    exists (select 1 from public.profiles where id = auth.uid() and role in ('admin_principal', 'admin_centro'))
);
create policy "Estudantes consultam os seus pagamentos" on public.payments for select using (
    exists (select 1 from public.students where id = payments.student_id and user_id = auth.uid())
);
create policy "Acesso a taxas" on public.fees for select using (true);

-- 4.9. Notificações, Auditoria e Configurações
create policy "Utilizadores vêem suas notificações" on public.notifications
    for all using (user_id = auth.uid() or user_id is null);

create policy "Admin principal consulta auditoria" on public.audit_logs
    for select using (
        exists (select 1 from public.profiles where id = auth.uid() and role = 'admin_principal')
    );
create policy "Sistema insere auditoria" on public.audit_logs
    for insert with check (true);

create policy "Configurações institucionais públicas para leitura" on public.institution_settings
    for select using (true);
create policy "Admin principal edita configurações" on public.institution_settings
    for all using (
        exists (select 1 from public.profiles where id = auth.uid() and role = 'admin_principal')
    );

-- ==============================================================================
-- 5. STORAGE BUCKET (Documentos de Candidatura)
-- ==============================================================================

insert into storage.buckets (id, name, public)
values ('application-documents', 'application-documents', false)
on conflict (id) do nothing;

create policy "Upload de documentos de candidatura permitido"
on storage.objects for insert
with check (bucket_id = 'application-documents');

create policy "Leitura de documentos de candidatura por staff"
on storage.objects for select
using (
    bucket_id = 'application-documents' and (
        exists (select 1 from public.profiles where id = auth.uid() and role in ('admin_principal', 'admin_centro'))
    )
);

-- ==============================================================================
-- 6. DADOS INICIAIS (SEEDS INSTITUCIONAIS DA AFPJV)
-- ==============================================================================

insert into public.institution_settings (id, institution_name, facebook_url, minimum_age, maximum_age)
values (
    'default',
    'Associação de Formação Profissional Jovens Valentes',
    'https://www.facebook.com/profile.php?id=61575852942153',
    17,
    45
) on conflict (id) do nothing;

-- Centros iniciais
insert into public.centers (id, name, location, phone, email, active)
values
    ('11111111-1111-1111-1111-111111111111', 'Centro de Recursos de Maputo (Sede)', 'Av. Karl Marx, Maputo', '+258 84 000 0000', 'maputo@afpjv.org.mz', true),
    ('22222222-2222-2222-2222-222222222222', 'Centro de Formação da Matola', 'Matola ' || 'G', '+258 84 000 0001', 'matola@afpjv.org.mz', true),
    ('33333333-3333-3333-3333-333333333333', 'Centro de Formação de Xai-Xai', 'Xai-Xai, Gaza', '+258 84 000 0002', 'xaixai@afpjv.org.mz', true)
on conflict (id) do nothing;

-- Cursos iniciais
insert into public.courses (id, name, center_id, registration_fee, monthly_fee, duration, active)
values
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Informática e Tecnologias de Informação', '11111111-1111-1111-1111-111111111111', 500.00, 1500.00, '6 meses', true),
    ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Culinária, Pastelaria e Panificação', '11111111-1111-1111-1111-111111111111', 500.00, 1800.00, '6 meses', true),
    ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'Eletricidade Instaladora Predial', '22222222-2222-2222-2222-222222222222', 600.00, 2000.00, '6 meses', true),
    ('dddddddd-dddd-dddd-dddd-dddddddddddd', 'Contabilidade Prática e Gestão de Negócios', '11111111-1111-1111-1111-111111111111', 500.00, 1600.00, '6 meses', true),
    ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'Corte e Costura Industrial', '22222222-2222-2222-2222-222222222222', 450.00, 1400.00, '4 meses', true)
on conflict (id) do nothing;
