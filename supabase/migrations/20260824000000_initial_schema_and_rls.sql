-- ============================================================================
-- Supabase PostgreSQL Initial Schema & Row Level Security (RLS)
-- Offline-First Finance & Construction Management App
-- ============================================================================

-- Ensure pgcrypto or uuid-ossp extension is enabled for UUID generation
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================================
-- 1. GLOBAL / REFERENCE TABLES (Shared reference data across users)
-- ============================================================================

-- 1.1 Roles Reference Table
-- Shared lookup table defining person roles.
CREATE TABLE IF NOT EXISTS public.roles (
    code TEXT PRIMARY KEY,
    display_name TEXT NOT NULL,
    sort_order INTEGER NOT NULL
);

-- Enable RLS on roles
ALTER TABLE public.roles ENABLE ROW LEVEL SECURITY;

-- Allow all authenticated and anonymous users read-only access to system roles
CREATE POLICY "Allow public read-only access to roles"
    ON public.roles
    FOR SELECT
    USING (true);

-- Seed standard system roles
INSERT INTO public.roles (code, display_name, sort_order) VALUES
    ('sdo', 'SDO', 10),
    ('engineer', 'Engineer', 20),
    ('xen', 'XEN', 30),
    ('peon', 'Peon', 40),
    ('do', 'DO', 50),
    ('accountant', 'Accountant', 60),
    ('clerk', 'Clerk', 70),
    ('driver', 'Driver', 80),
    ('labour', 'Labour', 90),
    ('security', 'Security', 100),
    ('other', 'Other', 110)
ON CONFLICT (code) DO UPDATE
SET display_name = EXCLUDED.display_name,
    sort_order = EXCLUDED.sort_order;


-- ============================================================================
-- 2. USER-OWNED BUSINESS TABLES
-- All records are strictly isolated by `user_id UUID REFERENCES auth.users(id)`.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 2.1 People Table
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.people (
    id TEXT PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE DEFAULT auth.uid(),
    full_name TEXT NOT NULL,
    phone_number TEXT NULL,
    email TEXT NULL,
    address TEXT NULL,
    notes TEXT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    deleted_at TIMESTAMPTZ NULL,
    remote_updated_at TIMESTAMPTZ NULL
);

ALTER TABLE public.people ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own people"
    ON public.people FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own people"
    ON public.people FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own people"
    ON public.people FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own people"
    ON public.people FOR DELETE
    USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_people_user_id ON public.people(user_id);
CREATE INDEX IF NOT EXISTS idx_people_deleted_at ON public.people(deleted_at);
CREATE INDEX IF NOT EXISTS idx_people_updated_at ON public.people(updated_at);


-- ----------------------------------------------------------------------------
-- 2.2 Person Roles Table (Child / Join Table)
-- Must include user_id to enforce RLS and foreign-key check against people.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.person_roles (
    person_id TEXT NOT NULL REFERENCES public.people(id) ON DELETE CASCADE,
    role_code TEXT NOT NULL REFERENCES public.roles(code) ON DELETE RESTRICT,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE DEFAULT auth.uid(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    PRIMARY KEY (person_id, role_code)
);

ALTER TABLE public.person_roles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own person_roles"
    ON public.person_roles FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own person_roles"
    ON public.person_roles FOR INSERT
    WITH CHECK (
        auth.uid() = user_id
        AND EXISTS (
            SELECT 1 FROM public.people p
            WHERE p.id = person_id AND p.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can update their own person_roles"
    ON public.person_roles FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own person_roles"
    ON public.person_roles FOR DELETE
    USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_person_roles_user_id ON public.person_roles(user_id);
CREATE INDEX IF NOT EXISTS idx_person_roles_person_id ON public.person_roles(person_id);
CREATE INDEX IF NOT EXISTS idx_person_roles_role_code ON public.person_roles(role_code);


-- ----------------------------------------------------------------------------
-- 2.3 Sites Table
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.sites (
    id TEXT PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE DEFAULT auth.uid(),
    name TEXT NOT NULL,
    road_info TEXT NULL,
    latitude DOUBLE PRECISION NULL,
    longitude DOUBLE PRECISION NULL,
    status TEXT NOT NULL DEFAULT 'active',
    notes TEXT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    deleted_at TIMESTAMPTZ NULL,
    remote_updated_at TIMESTAMPTZ NULL
);

ALTER TABLE public.sites ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own sites"
    ON public.sites FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own sites"
    ON public.sites FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own sites"
    ON public.sites FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own sites"
    ON public.sites FOR DELETE
    USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_sites_user_id ON public.sites(user_id);
CREATE INDEX IF NOT EXISTS idx_sites_deleted_at ON public.sites(deleted_at);
CREATE INDEX IF NOT EXISTS idx_sites_updated_at ON public.sites(updated_at);


-- ----------------------------------------------------------------------------
-- 2.4 Schemes Table
-- Budget is in paisa (BIGINT / INTEGER >= 0, 1 PKR = 100 paisa).
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.schemes (
    id TEXT PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE DEFAULT auth.uid(),
    scheme_code TEXT NOT NULL,
    name TEXT NOT NULL,
    site_id TEXT NULL REFERENCES public.sites(id) ON DELETE SET NULL,
    budget BIGINT NOT NULL DEFAULT 0,
    engineer_id TEXT NULL REFERENCES public.people(id) ON DELETE SET NULL,
    start_date TIMESTAMPTZ NULL,
    end_date TIMESTAMPTZ NULL,
    status TEXT NOT NULL DEFAULT 'initial',
    progress_percentage DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    incomplete_reason TEXT NULL,
    result TEXT NULL,
    description TEXT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    deleted_at TIMESTAMPTZ NULL,
    remote_updated_at TIMESTAMPTZ NULL,
    CONSTRAINT chk_schemes_budget_positive CHECK (budget >= 0),
    CONSTRAINT chk_schemes_progress CHECK (progress_percentage >= 0.0 AND progress_percentage <= 100.0)
);

ALTER TABLE public.schemes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own schemes"
    ON public.schemes FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own schemes"
    ON public.schemes FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own schemes"
    ON public.schemes FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own schemes"
    ON public.schemes FOR DELETE
    USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_schemes_user_id ON public.schemes(user_id);
CREATE INDEX IF NOT EXISTS idx_schemes_site_id ON public.schemes(site_id);
CREATE INDEX IF NOT EXISTS idx_schemes_engineer_id ON public.schemes(engineer_id);
CREATE INDEX IF NOT EXISTS idx_schemes_deleted_at ON public.schemes(deleted_at);
CREATE INDEX IF NOT EXISTS idx_schemes_updated_at ON public.schemes(updated_at);


-- ----------------------------------------------------------------------------
-- 2.5 Transactions Table
-- Amount in paisa (BIGINT >= 0). Type is 'received' or 'paid'.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.transactions (
    id TEXT PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE DEFAULT auth.uid(),
    transaction_code TEXT NOT NULL,
    transaction_date TIMESTAMPTZ NOT NULL,
    type TEXT NOT NULL,
    person_id TEXT NULL REFERENCES public.people(id) ON DELETE SET NULL,
    amount BIGINT NOT NULL DEFAULT 0,
    quantity DOUBLE PRECISION NULL,
    purpose TEXT NOT NULL,
    payment_method TEXT NOT NULL DEFAULT 'cash',
    reference_number TEXT NULL,
    remarks TEXT NULL,
    scheme_id TEXT NULL REFERENCES public.schemes(id) ON DELETE SET NULL,
    site_id TEXT NULL REFERENCES public.sites(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    deleted_at TIMESTAMPTZ NULL,
    remote_updated_at TIMESTAMPTZ NULL,
    CONSTRAINT chk_transactions_type CHECK (type IN ('received', 'paid')),
    CONSTRAINT chk_transactions_amount_positive CHECK (amount >= 0)
);

ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own transactions"
    ON public.transactions FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own transactions"
    ON public.transactions FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own transactions"
    ON public.transactions FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own transactions"
    ON public.transactions FOR DELETE
    USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_transactions_user_id ON public.transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_transactions_scheme_id ON public.transactions(scheme_id);
CREATE INDEX IF NOT EXISTS idx_transactions_site_id ON public.transactions(site_id);
CREATE INDEX IF NOT EXISTS idx_transactions_person_id ON public.transactions(person_id);
CREATE INDEX IF NOT EXISTS idx_transactions_deleted_at ON public.transactions(deleted_at);
CREATE INDEX IF NOT EXISTS idx_transactions_updated_at ON public.transactions(updated_at);


-- ----------------------------------------------------------------------------
-- 2.6 Expenses Table
-- Amount in paisa (BIGINT >= 0).
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.expenses (
    id TEXT PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE DEFAULT auth.uid(),
    expense_code TEXT NOT NULL,
    expense_date TIMESTAMPTZ NOT NULL,
    category TEXT NOT NULL,
    amount BIGINT NOT NULL DEFAULT 0,
    purpose TEXT NOT NULL,
    site_id TEXT NULL REFERENCES public.sites(id) ON DELETE SET NULL,
    scheme_id TEXT NULL REFERENCES public.schemes(id) ON DELETE SET NULL,
    person_id TEXT NULL REFERENCES public.people(id) ON DELETE SET NULL,
    remarks TEXT NULL,
    attachment_path TEXT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    deleted_at TIMESTAMPTZ NULL,
    remote_updated_at TIMESTAMPTZ NULL,
    CONSTRAINT chk_expenses_amount_positive CHECK (amount >= 0)
);

ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own expenses"
    ON public.expenses FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own expenses"
    ON public.expenses FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own expenses"
    ON public.expenses FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own expenses"
    ON public.expenses FOR DELETE
    USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_expenses_user_id ON public.expenses(user_id);
CREATE INDEX IF NOT EXISTS idx_expenses_scheme_id ON public.expenses(scheme_id);
CREATE INDEX IF NOT EXISTS idx_expenses_site_id ON public.expenses(site_id);
CREATE INDEX IF NOT EXISTS idx_expenses_person_id ON public.expenses(person_id);
CREATE INDEX IF NOT EXISTS idx_expenses_deleted_at ON public.expenses(deleted_at);
CREATE INDEX IF NOT EXISTS idx_expenses_updated_at ON public.expenses(updated_at);


-- ----------------------------------------------------------------------------
-- 2.7 Vehicles Table
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.vehicles (
    id TEXT PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE DEFAULT auth.uid(),
    vehicle_number TEXT NOT NULL,
    make_model TEXT NOT NULL,
    vehicle_type TEXT NOT NULL DEFAULT 'truck',
    assigned_site_id TEXT NULL REFERENCES public.sites(id) ON DELETE SET NULL,
    assigned_driver_id TEXT NULL REFERENCES public.people(id) ON DELETE SET NULL,
    status TEXT NOT NULL DEFAULT 'active',
    remarks TEXT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    deleted_at TIMESTAMPTZ NULL,
    remote_updated_at TIMESTAMPTZ NULL
);

ALTER TABLE public.vehicles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own vehicles"
    ON public.vehicles FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own vehicles"
    ON public.vehicles FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own vehicles"
    ON public.vehicles FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own vehicles"
    ON public.vehicles FOR DELETE
    USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_vehicles_user_id ON public.vehicles(user_id);
CREATE INDEX IF NOT EXISTS idx_vehicles_assigned_site_id ON public.vehicles(assigned_site_id);
CREATE INDEX IF NOT EXISTS idx_vehicles_assigned_driver_id ON public.vehicles(assigned_driver_id);
CREATE INDEX IF NOT EXISTS idx_vehicles_deleted_at ON public.vehicles(deleted_at);
CREATE INDEX IF NOT EXISTS idx_vehicles_updated_at ON public.vehicles(updated_at);


-- ----------------------------------------------------------------------------
-- 2.8 Vehicle Logs Table (Child Table of Vehicles)
-- Amount in paisa (BIGINT >= 0).
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.vehicle_logs (
    id TEXT PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE DEFAULT auth.uid(),
    vehicle_id TEXT NOT NULL REFERENCES public.vehicles(id) ON DELETE CASCADE,
    log_date TIMESTAMPTZ NOT NULL,
    log_type TEXT NOT NULL,
    amount BIGINT NOT NULL DEFAULT 0,
    quantity_liters DOUBLE PRECISION NULL,
    driver_id TEXT NULL REFERENCES public.people(id) ON DELETE SET NULL,
    site_id TEXT NULL REFERENCES public.sites(id) ON DELETE SET NULL,
    description TEXT NOT NULL,
    odometer_reading DOUBLE PRECISION NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    deleted_at TIMESTAMPTZ NULL,
    remote_updated_at TIMESTAMPTZ NULL,
    CONSTRAINT chk_vehicle_logs_amount_positive CHECK (amount >= 0)
);

ALTER TABLE public.vehicle_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own vehicle_logs"
    ON public.vehicle_logs FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own vehicle_logs"
    ON public.vehicle_logs FOR INSERT
    WITH CHECK (
        auth.uid() = user_id
        AND EXISTS (
            SELECT 1 FROM public.vehicles v
            WHERE v.id = vehicle_id AND v.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can update their own vehicle_logs"
    ON public.vehicle_logs FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own vehicle_logs"
    ON public.vehicle_logs FOR DELETE
    USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_vehicle_logs_user_id ON public.vehicle_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_vehicle_logs_vehicle_id ON public.vehicle_logs(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_vehicle_logs_deleted_at ON public.vehicle_logs(deleted_at);
CREATE INDEX IF NOT EXISTS idx_vehicle_logs_updated_at ON public.vehicle_logs(updated_at);


-- ----------------------------------------------------------------------------
-- 2.9 Bills Table (Child Table of Schemes)
-- Amount in paisa (BIGINT >= 0).
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.bills (
    id TEXT PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE DEFAULT auth.uid(),
    scheme_id TEXT NOT NULL REFERENCES public.schemes(id) ON DELETE CASCADE,
    bill_type TEXT NOT NULL,
    bill_number TEXT NULL,
    bill_date TIMESTAMPTZ NOT NULL,
    amount BIGINT NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'draft',
    remarks TEXT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    deleted_at TIMESTAMPTZ NULL,
    remote_updated_at TIMESTAMPTZ NULL,
    CONSTRAINT chk_bills_amount_positive CHECK (amount >= 0)
);

ALTER TABLE public.bills ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own bills"
    ON public.bills FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own bills"
    ON public.bills FOR INSERT
    WITH CHECK (
        auth.uid() = user_id
        AND EXISTS (
            SELECT 1 FROM public.schemes s
            WHERE s.id = scheme_id AND s.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can update their own bills"
    ON public.bills FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own bills"
    ON public.bills FOR DELETE
    USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_bills_user_id ON public.bills(user_id);
CREATE INDEX IF NOT EXISTS idx_bills_scheme_id ON public.bills(scheme_id);
CREATE INDEX IF NOT EXISTS idx_bills_deleted_at ON public.bills(deleted_at);
CREATE INDEX IF NOT EXISTS idx_bills_updated_at ON public.bills(updated_at);


-- ----------------------------------------------------------------------------
-- 2.10 Progress Updates Table (Child Table of Schemes / Sites)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.progress_updates (
    id TEXT PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE DEFAULT auth.uid(),
    scheme_id TEXT NOT NULL REFERENCES public.schemes(id) ON DELETE CASCADE,
    site_id TEXT NULL REFERENCES public.sites(id) ON DELETE SET NULL,
    status TEXT NOT NULL,
    progress_percentage DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    date TIMESTAMPTZ NOT NULL,
    incomplete_reason TEXT NULL,
    result TEXT NULL,
    remarks TEXT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    deleted_at TIMESTAMPTZ NULL,
    remote_updated_at TIMESTAMPTZ NULL,
    CONSTRAINT chk_progress_percentage CHECK (progress_percentage >= 0.0 AND progress_percentage <= 100.0)
);

ALTER TABLE public.progress_updates ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own progress_updates"
    ON public.progress_updates FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own progress_updates"
    ON public.progress_updates FOR INSERT
    WITH CHECK (
        auth.uid() = user_id
        AND EXISTS (
            SELECT 1 FROM public.schemes s
            WHERE s.id = scheme_id AND s.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can update their own progress_updates"
    ON public.progress_updates FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own progress_updates"
    ON public.progress_updates FOR DELETE
    USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_progress_updates_user_id ON public.progress_updates(user_id);
CREATE INDEX IF NOT EXISTS idx_progress_updates_scheme_id ON public.progress_updates(scheme_id);
CREATE INDEX IF NOT EXISTS idx_progress_updates_site_id ON public.progress_updates(site_id);
CREATE INDEX IF NOT EXISTS idx_progress_updates_deleted_at ON public.progress_updates(deleted_at);
CREATE INDEX IF NOT EXISTS idx_progress_updates_updated_at ON public.progress_updates(updated_at);


-- ----------------------------------------------------------------------------
-- 2.11 Reminders Table
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.reminders (
    id TEXT PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE DEFAULT auth.uid(),
    title TEXT NOT NULL,
    description TEXT NULL,
    due_at TIMESTAMPTZ NULL,
    priority TEXT NOT NULL DEFAULT 'medium',
    is_done BOOLEAN NOT NULL DEFAULT false,
    done_at TIMESTAMPTZ NULL,
    scheme_id TEXT NULL REFERENCES public.schemes(id) ON DELETE SET NULL,
    site_id TEXT NULL REFERENCES public.sites(id) ON DELETE SET NULL,
    remarks TEXT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    deleted_at TIMESTAMPTZ NULL,
    remote_updated_at TIMESTAMPTZ NULL
);

ALTER TABLE public.reminders ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own reminders"
    ON public.reminders FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own reminders"
    ON public.reminders FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own reminders"
    ON public.reminders FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own reminders"
    ON public.reminders FOR DELETE
    USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_reminders_user_id ON public.reminders(user_id);
CREATE INDEX IF NOT EXISTS idx_reminders_scheme_id ON public.reminders(scheme_id);
CREATE INDEX IF NOT EXISTS idx_reminders_site_id ON public.reminders(site_id);
CREATE INDEX IF NOT EXISTS idx_reminders_due_at ON public.reminders(due_at);
CREATE INDEX IF NOT EXISTS idx_reminders_deleted_at ON public.reminders(deleted_at);
CREATE INDEX IF NOT EXISTS idx_reminders_updated_at ON public.reminders(updated_at);


-- ----------------------------------------------------------------------------
-- 2.12 Reminder Entity Links Table (Child Table of Reminders)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.reminder_entity_links (
    id TEXT PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE DEFAULT auth.uid(),
    reminder_id TEXT NOT NULL REFERENCES public.reminders(id) ON DELETE CASCADE,
    entity_type TEXT NOT NULL,
    entity_id TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    deleted_at TIMESTAMPTZ NULL,
    remote_updated_at TIMESTAMPTZ NULL,
    CONSTRAINT uq_reminder_entity_link UNIQUE (reminder_id, entity_type, entity_id)
);

ALTER TABLE public.reminder_entity_links ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own reminder_entity_links"
    ON public.reminder_entity_links FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own reminder_entity_links"
    ON public.reminder_entity_links FOR INSERT
    WITH CHECK (
        auth.uid() = user_id
        AND EXISTS (
            SELECT 1 FROM public.reminders r
            WHERE r.id = reminder_id AND r.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can update their own reminder_entity_links"
    ON public.reminder_entity_links FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own reminder_entity_links"
    ON public.reminder_entity_links FOR DELETE
    USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_reminder_entity_links_user_id ON public.reminder_entity_links(user_id);
CREATE INDEX IF NOT EXISTS idx_reminder_entity_links_reminder_id ON public.reminder_entity_links(reminder_id);
CREATE INDEX IF NOT EXISTS idx_reminder_entity_links_entity ON public.reminder_entity_links(entity_type, entity_id);


-- ----------------------------------------------------------------------------
-- 2.13 Attachments Table (Metadata for files in Supabase Storage)
-- Records metadata only; file binaries belong in Supabase Storage bucket.
-- Includes `storage_path` for cloud location in addition to local file attributes.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.attachments (
    id TEXT PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE DEFAULT auth.uid(),
    entity_type TEXT NOT NULL,
    entity_id TEXT NOT NULL,
    file_path TEXT NULL,
    file_name TEXT NOT NULL,
    storage_path TEXT NULL,
    mime_type TEXT NULL,
    file_size INTEGER NULL,
    image_width INTEGER NULL,
    image_height INTEGER NULL,
    category TEXT NOT NULL DEFAULT 'other',
    description TEXT NULL,
    captured_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    latitude DOUBLE PRECISION NULL,
    longitude DOUBLE PRECISION NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    deleted_at TIMESTAMPTZ NULL,
    remote_updated_at TIMESTAMPTZ NULL
);

ALTER TABLE public.attachments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own attachments"
    ON public.attachments FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own attachments"
    ON public.attachments FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own attachments"
    ON public.attachments FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own attachments"
    ON public.attachments FOR DELETE
    USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_attachments_user_id ON public.attachments(user_id);
CREATE INDEX IF NOT EXISTS idx_attachments_entity ON public.attachments(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_attachments_deleted_at ON public.attachments(deleted_at);
CREATE INDEX IF NOT EXISTS idx_attachments_updated_at ON public.attachments(updated_at);


-- ============================================================================
-- 3. AUTOMATIC updated_at / remote_updated_at TRIGGER
-- Automatically updates updated_at whenever a cloud record is modified.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = timezone('utc'::text, now());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$
DECLARE
    t text;
    user_tables text[] := ARRAY[
        'people',
        'sites',
        'schemes',
        'transactions',
        'expenses',
        'vehicles',
        'vehicle_logs',
        'bills',
        'progress_updates',
        'reminders',
        'reminder_entity_links',
        'attachments'
    ];
BEGIN
    FOREACH t IN ARRAY user_tables LOOP
        EXECUTE format('
            DROP TRIGGER IF EXISTS trigger_set_updated_at ON public.%I;
            CREATE TRIGGER trigger_set_updated_at
            BEFORE UPDATE ON public.%I
            FOR EACH ROW
            EXECUTE FUNCTION public.handle_updated_at();
        ', t, t);
    END LOOP;
END;
$$;
