-- Create a secure function to get user email
CREATE OR REPLACE FUNCTION auth.get_user_email(user_id UUID)
RETURNS TEXT
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT email FROM auth.users WHERE id = user_id;
$$;

-- Create a secure function to get users list for admins
CREATE OR REPLACE FUNCTION auth.get_users_list()
RETURNS TABLE (
    id UUID,
    email TEXT,
    is_admin BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Check if the current user is an admin
    IF EXISTS (
        SELECT 1 FROM public.user_roles 
        WHERE id = auth.uid() 
        AND is_admin = true
    ) THEN
        RETURN QUERY
        SELECT 
            u.id,
            u.email,
            COALESCE(ur.is_admin, false)
        FROM auth.users u
        LEFT JOIN public.user_roles ur ON ur.id = u.id;
    ELSE
        -- Return only the current user's information
        RETURN QUERY
        SELECT 
            u.id,
            u.email,
            COALESCE(ur.is_admin, false)
        FROM auth.users u
        LEFT JOIN public.user_roles ur ON ur.id = u.id
        WHERE u.id = auth.uid();
    END IF;
END;
$$;

-- Drop existing views
DROP VIEW IF EXISTS public.driver_permissions_view CASCADE;
DROP VIEW IF EXISTS public.user_roles_view CASCADE;

-- Create user_roles_view using the secure function
CREATE VIEW public.user_roles_view AS
SELECT * FROM auth.get_users_list();

-- Recreate driver_permissions_view
CREATE VIEW public.driver_permissions_view AS
SELECT 
    dp.id,
    dp.user_id,
    dp.is_approved,
    dp.approved_by,
    dp.approved_at,
    dp.created_at,
    dp.updated_at,
    auth.get_user_email(dp.user_id) as user_email
FROM public.driver_permissions dp;

-- Grant necessary permissions
GRANT USAGE ON SCHEMA auth TO authenticated;
GRANT EXECUTE ON FUNCTION auth.get_user_email TO authenticated;
GRANT EXECUTE ON FUNCTION auth.get_users_list TO authenticated;
GRANT SELECT ON public.user_roles_view TO authenticated;
GRANT SELECT ON public.driver_permissions_view TO authenticated;