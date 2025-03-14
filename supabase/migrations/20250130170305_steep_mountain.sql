-- Drop existing view and policies
DROP VIEW IF EXISTS public.user_roles_view;
DROP POLICY IF EXISTS "Anyone can view roles" ON public.user_roles;

-- Create a secure function to get user email
CREATE OR REPLACE FUNCTION auth.get_user_email_secure(user_id UUID)
RETURNS TEXT
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT email FROM auth.users WHERE id = user_id;
$$;

-- Grant execute permission on the secure function
GRANT EXECUTE ON FUNCTION auth.get_user_email_secure TO authenticated;

-- Create view with secure email access
CREATE VIEW public.user_roles_view AS
SELECT 
    ur.id,
    auth.get_user_email_secure(ur.id) as email,
    ur.is_admin
FROM public.user_roles ur;

-- Enable RLS on the view
ALTER VIEW public.user_roles_view SET (security_invoker = true);

-- Grant necessary permissions
GRANT SELECT ON public.user_roles_view TO authenticated;

-- Create policies for user_roles table
CREATE POLICY "Users can view their own role"
    ON public.user_roles
    FOR SELECT
    TO authenticated
    USING (auth.uid() = id);

CREATE POLICY "Admins can view all roles"
    ON public.user_roles
    FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_roles
            WHERE id = auth.uid() AND is_admin = true
        )
    );