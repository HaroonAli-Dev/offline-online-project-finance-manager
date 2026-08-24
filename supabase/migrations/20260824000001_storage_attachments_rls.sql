-- ============================================================================
-- Supabase Storage Policies for 'attachments' Bucket (Idempotent Migration)
-- Ensures authenticated users can only access and modify their own files.
-- Path convention: {user_id}/{entity_type}/{attachment_id}/{file_name}
-- ============================================================================

-- Ensure storage bucket exists (if not already created)
INSERT INTO storage.buckets (id, name, public)
VALUES ('attachments', 'attachments', false)
ON CONFLICT (id) DO NOTHING;

-- 1. SELECT (Download/Read): Users can read objects in 'attachments' if the object path starts with their auth.uid()
DROP POLICY IF EXISTS "Users can read their own attachments in storage" ON storage.objects;
CREATE POLICY "Users can read their own attachments in storage"
ON storage.objects FOR SELECT
TO authenticated
USING (
    bucket_id = 'attachments'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- 2. INSERT (Upload): Users can upload objects to 'attachments' bucket only into their own folder prefix
DROP POLICY IF EXISTS "Users can upload their own attachments in storage" ON storage.objects;
CREATE POLICY "Users can upload their own attachments in storage"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'attachments'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- 3. UPDATE: Users can update objects in their own folder
DROP POLICY IF EXISTS "Users can update their own attachments in storage" ON storage.objects;
CREATE POLICY "Users can update their own attachments in storage"
ON storage.objects FOR UPDATE
TO authenticated
USING (
    bucket_id = 'attachments'
    AND (storage.foldername(name))[1] = auth.uid()::text
)
WITH CHECK (
    bucket_id = 'attachments'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- 4. DELETE: Users can delete objects in their own folder
DROP POLICY IF EXISTS "Users can delete their own attachments in storage" ON storage.objects;
CREATE POLICY "Users can delete their own attachments in storage"
ON storage.objects FOR DELETE
TO authenticated
USING (
    bucket_id = 'attachments'
    AND (storage.foldername(name))[1] = auth.uid()::text
);
