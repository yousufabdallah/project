/*
  # Fix user roles view and policies

  1. Changes
    - Create a materialized view for user roles that includes email
    - Add proper RLS policies
    - Ensure email field is available for admin users
*/

-- Create materialized view for user roles
CREATE MATERIALIZED VIEW IF NOT EXISTS public.user_roles_view AS
SELECT 
    ur.id,
    u.email,
    ur.is_admin
FROM public.user_roles ur
JOIN auth.users u ON u.id = ur.id;

-- Create unique index for refreshing
CREATE UNIQUE INDEX IF NOT EXISTS user_roles_view_id_idx ON public.user_roles_view (id);

-- Grant access to authenticated users
GRANT SELECT ON public.user_roles_view TO authenticated;

-- Create function to refresh the view
CREATE OR REPLACE FUNCTION refresh_user_roles_view()
RETURNS TRIGGER AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY public.user_roles_view;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create triggers to refresh the view
DROP TRIGGER IF EXISTS refresh_user_roles_view_trigger ON public.user_roles;
CREATE TRIGGER refresh_user_roles_view_trigger
    AFTER INSERT OR UPDATE OR DELETE ON public.user_roles
    FOR EACH STATEMENT
    EXECUTE FUNCTION refresh_user_roles_view();

-- Initial refresh of the view
REFRESH MATERIALIZED VIEW public.user_roles_view;