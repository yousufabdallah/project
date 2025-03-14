-- Drop existing views and policies first
DROP VIEW IF EXISTS public.user_roles_view;
DROP POLICY IF EXISTS "Basic access policy" ON public.user_roles;
DROP POLICY IF EXISTS "Admin update policy" ON public.user_roles;

-- Create simplified view without complex logic
CREATE VIEW public.user_roles_view AS
SELECT 
    ur.id,
    u.email,
    ur.is_admin
FROM public.user_roles ur
JOIN auth.users u ON u.id = ur.id;

-- Enable RLS on the view
ALTER VIEW public.user_roles_view SET (security_invoker = true);

-- Grant necessary permissions
GRANT SELECT ON public.user_roles_view TO authenticated;

-- Create simplified policies that avoid recursion
CREATE POLICY "View own role"
    ON public.user_roles
    FOR SELECT
    TO authenticated
    USING (
        -- Users can always view their own role
        auth.uid() = id
        OR
        -- Admins can view all roles (using metadata directly)
        EXISTS (
            SELECT 1 FROM auth.users
            WHERE id = auth.uid()
            AND (raw_user_meta_data->>'is_admin')::boolean = true
        )
    );

CREATE POLICY "Admin manage roles"
    ON public.user_roles
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM auth.users
            WHERE id = auth.uid()
            AND (raw_user_meta_data->>'is_admin')::boolean = true
        )
    );

-- Ensure admin user exists with correct privileges
DO $$ 
DECLARE
    admin_id UUID;
BEGIN
    -- Get admin user ID
    SELECT id INTO admin_id
    FROM auth.users
    WHERE email = 'yousufabdallah2000@gmail.com';

    IF admin_id IS NOT NULL THEN
        -- Update or insert admin role
        INSERT INTO public.user_roles (id, is_admin, meta_is_admin)
        VALUES (admin_id, true, 'true')
        ON CONFLICT (id) DO UPDATE
        SET is_admin = true, meta_is_admin = 'true', updated_at = now();
    END IF;
END $$;