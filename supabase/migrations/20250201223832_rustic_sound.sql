-- Drop all existing policies on driver_permissions
DROP POLICY IF EXISTS "View driver permissions" ON public.driver_permissions;
DROP POLICY IF EXISTS "Create driver permissions" ON public.driver_permissions;
DROP POLICY IF EXISTS "Update driver permissions" ON public.driver_permissions;
DROP POLICY IF EXISTS "driver_permissions_select" ON public.driver_permissions;
DROP POLICY IF EXISTS "driver_permissions_insert" ON public.driver_permissions;
DROP POLICY IF EXISTS "driver_permissions_update" ON public.driver_permissions;
DROP POLICY IF EXISTS "Users can view their own driver permission" ON public.driver_permissions;
DROP POLICY IF EXISTS "Admins can manage driver permissions" ON public.driver_permissions;
DROP POLICY IF EXISTS "Users can request driver permission" ON public.driver_permissions;

-- Create new simplified policies without recursion
CREATE POLICY "driver_permissions_select"
    ON public.driver_permissions
    FOR SELECT
    TO authenticated
    USING (
        -- Users can view their own permissions
        auth.uid() = user_id
        OR 
        -- Admins can view all permissions (using auth.users metadata)
        EXISTS (
            SELECT 1 FROM auth.users
            WHERE id = auth.uid()
            AND (raw_user_meta_data->>'is_admin')::boolean = true
        )
    );

CREATE POLICY "driver_permissions_insert"
    ON public.driver_permissions
    FOR INSERT
    TO authenticated
    WITH CHECK (
        -- Users can only create their own permissions
        auth.uid() = user_id
        AND
        -- Only if they don't already have one
        NOT EXISTS (
            SELECT 1 FROM public.driver_permissions
            WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "driver_permissions_update"
    ON public.driver_permissions
    FOR UPDATE
    TO authenticated
    USING (
        -- Only admins can update permissions
        EXISTS (
            SELECT 1 FROM auth.users
            WHERE id = auth.uid()
            AND (raw_user_meta_data->>'is_admin')::boolean = true
        )
    )
    WITH CHECK (
        -- Only admins can update permissions
        EXISTS (
            SELECT 1 FROM auth.users
            WHERE id = auth.uid()
            AND (raw_user_meta_data->>'is_admin')::boolean = true
        )
    );

-- Create view for driver permissions with user information
DROP VIEW IF EXISTS public.driver_permissions_view;
CREATE VIEW public.driver_permissions_view AS
SELECT 
    dp.id,
    dp.user_id,
    dp.is_approved,
    dp.approved_by,
    dp.approved_at,
    dp.created_at,
    dp.updated_at,
    u.email as user_email
FROM public.driver_permissions dp
JOIN auth.users u ON u.id = dp.user_id;

-- Grant necessary permissions
GRANT ALL ON public.driver_permissions TO authenticated;
GRANT SELECT ON public.driver_permissions_view TO authenticated;