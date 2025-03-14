/*
  # Allow non-admin users to log in
  
  1. Changes
    - Removes admin-only restrictions
    - Updates user roles policies to allow all authenticated users
*/

-- Drop existing policies
DROP POLICY IF EXISTS "Users can view their own role" ON public.user_roles;
DROP POLICY IF EXISTS "Admins can view all roles" ON public.user_roles;

-- Create new inclusive policies
CREATE POLICY "Users can view their own role"
    ON public.user_roles
    FOR SELECT
    TO authenticated
    USING (auth.uid() = id);

CREATE POLICY "Admins can manage all roles"
    ON public.user_roles
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_roles AS ur
            WHERE ur.id = auth.uid() AND (ur.is_admin = true OR ur.meta_is_admin = 'true')
        )
    );

-- Update sync_user_roles function to handle non-admin users
CREATE OR REPLACE FUNCTION public.sync_user_roles()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.user_roles (id, is_admin, meta_is_admin)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'is_admin' = 'true', false),
        NEW.raw_user_meta_data->>'is_admin'
    )
    ON CONFLICT (id) DO UPDATE
    SET
        is_admin = COALESCE(NEW.raw_user_meta_data->>'is_admin' = 'true', false),
        meta_is_admin = NEW.raw_user_meta_data->>'is_admin',
        updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;