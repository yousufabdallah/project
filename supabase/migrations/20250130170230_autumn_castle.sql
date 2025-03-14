-- Drop existing view
DROP VIEW IF EXISTS public.user_roles_view;

-- Create view with correct columns
CREATE OR REPLACE VIEW public.user_roles_view AS
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

-- Create policy for viewing the roles
CREATE POLICY "Anyone can view roles"
    ON public.user_roles
    FOR SELECT
    TO authenticated
    USING (true);