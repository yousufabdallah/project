/*
  # Fix permissions and views

  1. Create secure functions for user access
  2. Update views to use secure functions
  3. Fix RLS policies
*/

-- Create secure function to get user email
CREATE OR REPLACE FUNCTION auth.get_user_email(user_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN (
        SELECT email 
        FROM auth.users 
        WHERE id = user_id
    );
END;
$$;

-- Create secure function to check if user is admin
CREATE OR REPLACE FUNCTION auth.is_admin(user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 
        FROM auth.users 
        WHERE id = user_id
        AND (raw_user_meta_data->>'is_admin')::boolean = true
    );
END;
$$;

-- Drop existing views
DROP VIEW IF EXISTS public.driver_permissions_view;
DROP VIEW IF EXISTS public.driver_surveys_view;
DROP VIEW IF EXISTS public.office_assignments_view;

-- Drop existing policies
DROP POLICY IF EXISTS "driver_permissions_select" ON public.driver_permissions;
DROP POLICY IF EXISTS "driver_permissions_insert" ON public.driver_permissions;
DROP POLICY IF EXISTS "driver_permissions_update" ON public.driver_permissions;

-- Create new policies for driver_permissions
CREATE POLICY "driver_permissions_select"
    ON public.driver_permissions
    FOR SELECT
    TO authenticated
    USING (
        auth.uid() = user_id
        OR 
        auth.is_admin(auth.uid())
    );

CREATE POLICY "driver_permissions_insert"
    ON public.driver_permissions
    FOR INSERT
    TO authenticated
    WITH CHECK (
        auth.uid() = user_id
        AND
        NOT EXISTS (
            SELECT 1 FROM public.driver_permissions
            WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "driver_permissions_update"
    ON public.driver_permissions
    FOR UPDATE
    TO authenticated
    USING (auth.is_admin(auth.uid()))
    WITH CHECK (auth.is_admin(auth.uid()));

-- Recreate views using secure functions
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
FROM public.driver_permissions dp
WHERE 
    auth.uid() = dp.user_id
    OR 
    auth.is_admin(auth.uid());

CREATE VIEW public.driver_surveys_view AS
SELECT 
    ds.id,
    ds.user_id,
    ds.full_name,
    ds.tribe,
    ds.age,
    ds.car_type,
    ds.civil_id,
    ds.phone_number,
    ds.status,
    ds.created_at,
    ds.updated_at,
    auth.get_user_email(ds.user_id) as user_email
FROM public.driver_surveys ds
WHERE 
    auth.uid() = ds.user_id
    OR 
    auth.is_admin(auth.uid());

CREATE VIEW public.office_assignments_view AS
SELECT 
    oa.id,
    oa.region_id,
    oa.user_id,
    r.name as region_name,
    auth.get_user_email(oa.user_id) as user_email,
    oa.created_at,
    oa.updated_at
FROM public.office_assignments oa
JOIN public.regions r ON r.id = oa.region_id
WHERE 
    auth.uid() = oa.user_id
    OR 
    auth.is_admin(auth.uid());

-- Grant necessary permissions
GRANT USAGE ON SCHEMA auth TO authenticated;
GRANT EXECUTE ON FUNCTION auth.get_user_email TO authenticated;
GRANT EXECUTE ON FUNCTION auth.is_admin TO authenticated;
GRANT SELECT ON public.driver_permissions_view TO authenticated;
GRANT SELECT ON public.driver_surveys_view TO authenticated;
GRANT SELECT ON public.office_assignments_view TO authenticated;