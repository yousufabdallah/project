-- Drop existing policies
DROP POLICY IF EXISTS "shipping_requests_insert_policy" ON public.shipping_requests;
DROP POLICY IF EXISTS "shipping_requests_select_policy" ON public.shipping_requests;
DROP POLICY IF EXISTS "shipping_requests_update_policy" ON public.shipping_requests;
DROP POLICY IF EXISTS "Users can create shipping requests" ON public.shipping_requests;
DROP POLICY IF EXISTS "Office staff can view relevant requests" ON public.shipping_requests;
DROP POLICY IF EXISTS "Users can update their own requests" ON public.shipping_requests;

-- Create policy for creating shipping requests
CREATE POLICY "shipping_requests_insert_policy"
    ON public.shipping_requests
    FOR INSERT
    TO authenticated
    WITH CHECK (true);

-- Create policy for viewing shipping requests
CREATE POLICY "shipping_requests_select_policy"
    ON public.shipping_requests
    FOR SELECT
    TO authenticated
    USING (
        -- User owns the request
        auth.uid() = user_id
        OR
        -- Office staff can see requests from their office or delivered to their region
        EXISTS (
            SELECT 1 FROM public.office_assignments oa
            JOIN public.regions r ON r.id = oa.region_id
            WHERE oa.user_id = auth.uid()
            AND (
                -- Requests registered at their office
                oa.id = office_id
                OR
                -- Requests to be delivered to their region
                r.name = delivery_location
            )
        )
        OR
        -- Admin can see all requests
        EXISTS (
            SELECT 1 FROM public.user_roles
            WHERE id = auth.uid()
            AND is_admin = true
        )
    );

-- Create policy for updating shipping requests
CREATE POLICY "shipping_requests_update_policy"
    ON public.shipping_requests
    FOR UPDATE
    TO authenticated
    USING (
        -- User owns the request
        auth.uid() = user_id
        OR
        -- Office staff can update requests from their office
        EXISTS (
            SELECT 1 FROM public.office_assignments oa
            WHERE oa.user_id = auth.uid()
            AND oa.id = office_id
        )
        OR
        -- Admin can update all requests
        EXISTS (
            SELECT 1 FROM public.user_roles
            WHERE id = auth.uid()
            AND is_admin = true
        )
    )
    WITH CHECK (
        -- User owns the request
        auth.uid() = user_id
        OR
        -- Office staff can update requests from their office
        EXISTS (
            SELECT 1 FROM public.office_assignments oa
            WHERE oa.user_id = auth.uid()
            AND oa.id = office_id
        )
        OR
        -- Admin can update all requests
        EXISTS (
            SELECT 1 FROM public.user_roles
            WHERE id = auth.uid()
            AND is_admin = true
        )
    );