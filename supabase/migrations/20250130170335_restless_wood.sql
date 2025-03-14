-- Drop existing view and policies
DROP VIEW IF EXISTS public.user_roles_view;
DROP POLICY IF EXISTS "Users can view their own role" ON public.user_roles;
DROP POLICY IF EXISTS "Admins can view all roles" ON public.user_roles;

-- Create a secure function to get user email
CREATE OR REPLACE FUNCTION auth.get_user_email_secure(user_id UUID)
RETURNS TEXT
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT email FROM auth.users WHERE id = user_id;
$$;

-- Create a secure function to check admin status
CREATE OR REPLACE FUNCTION auth.is_admin(user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM auth.users
        WHERE id = user_id
        AND (raw_user_meta_data->>'is_admin')::boolean = true
    );
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION auth.get_user_email_secure TO authenticated;
GRANT EXECUTE ON FUNCTION auth.is_admin TO authenticated;

-- Create view with secure email access
CREATE VIEW public.user_roles_view AS
SELECT 
    ur.id,
    auth.get_user_email_secure(ur.id) as email,
    ur.is_admin
FROM public.user_roles ur
WHERE 
    -- User can see their own role
    auth.uid() = ur.id
    OR 
    -- Admins can see all roles
    auth.is_admin(auth.uid());

-- Enable RLS on the view
ALTER VIEW public.user_roles_view SET (security_invoker = true);

-- Grant necessary permissions
GRANT SELECT ON public.user_roles_view TO authenticated;

-- Create non-recursive policies for user_roles table
CREATE POLICY "Basic access policy"
    ON public.user_roles
    FOR SELECT
    TO authenticated
    USING (
        -- Users can always see their own role
        auth.uid() = id
        OR
        -- Admins can see all roles (using metadata directly)
        auth.is_admin(auth.uid())
    );

-- Policy for updating roles (admin only)
CREATE POLICY "Admin update policy"
    ON public.user_roles
    FOR UPDATE
    TO authenticated
    USING (auth.is_admin(auth.uid()))
    WITH CHECK (auth.is_admin(auth.uid()));