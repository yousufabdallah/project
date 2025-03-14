-- Create a secure function to get users list for admins
CREATE OR REPLACE FUNCTION auth.get_users_for_admin()
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

-- Grant execute permission on the function
GRANT EXECUTE ON FUNCTION auth.get_users_for_admin TO authenticated;

-- Drop dependent views first
DROP VIEW IF EXISTS public.driver_permissions_view CASCADE;
DROP VIEW IF EXISTS public.user_roles_view CASCADE;

-- Recreate the user_roles_view
CREATE VIEW public.user_roles_view AS
SELECT * FROM auth.get_users_for_admin();

-- Enable RLS on the view
ALTER VIEW public.user_roles_view SET (security_invoker = true);

-- Recreate the driver_permissions_view
CREATE OR REPLACE VIEW public.driver_permissions_view AS
SELECT 
    dp.*,
    urv.email as user_email
FROM public.driver_permissions dp
JOIN public.user_roles_view urv ON urv.id = dp.user_id;

-- Grant necessary permissions
GRANT SELECT ON public.user_roles_view TO authenticated;
GRANT SELECT ON public.driver_permissions_view TO authenticated;