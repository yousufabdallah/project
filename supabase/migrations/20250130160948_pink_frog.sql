-- Drop existing policies
DROP POLICY IF EXISTS "Users can view their own role" ON public.user_roles;
DROP POLICY IF EXISTS "Admins can view all roles" ON public.user_roles;

-- Create new simplified policies
CREATE POLICY "Anyone can view roles"
    ON public.user_roles
    FOR SELECT
    TO authenticated
    USING (true);

-- Update sync_user_roles function to be more robust
CREATE OR REPLACE FUNCTION public.sync_user_roles()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.user_roles (id, is_admin, meta_is_admin)
    VALUES (
        NEW.id,
        COALESCE((NEW.raw_user_meta_data->>'is_admin')::boolean, false),
        NEW.raw_user_meta_data->>'is_admin'
    )
    ON CONFLICT (id) DO UPDATE
    SET
        is_admin = COALESCE((NEW.raw_user_meta_data->>'is_admin')::boolean, false),
        meta_is_admin = NEW.raw_user_meta_data->>'is_admin',
        updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Ensure admin user exists with correct privileges
DO $$ 
BEGIN
    -- Update existing admin user if exists
    UPDATE auth.users
    SET raw_user_meta_data = jsonb_build_object('is_admin', true)
    WHERE email = 'yousufabdallah2000@gmail.com';

    -- Sync admin role
    INSERT INTO public.user_roles (id, is_admin, meta_is_admin)
    SELECT id, true, 'true'
    FROM auth.users
    WHERE email = 'yousufabdallah2000@gmail.com'
    ON CONFLICT (id) DO UPDATE
    SET is_admin = true, meta_is_admin = 'true', updated_at = now();
END $$;