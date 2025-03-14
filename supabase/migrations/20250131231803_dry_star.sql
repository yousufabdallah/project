-- Add office_id column to shipping_requests table
ALTER TABLE public.shipping_requests
ADD COLUMN office_id UUID REFERENCES public.office_assignments(id);

-- Update shipping_requests_with_users view to include office information
DROP VIEW IF EXISTS public.shipping_requests_with_users;

CREATE VIEW public.shipping_requests_with_users AS
SELECT 
    sr.id as request_id,
    sr.user_id,
    sr.pickup_location,
    sr.delivery_location,
    sr.description,
    sr.image_url,
    sr.status::text as status,
    sr.delivery_fee,
    sr.order_value,
    sr.is_paid,
    sr.office_id,
    sr.created_at,
    sr.updated_at,
    u1.email as user_email,
    u2.email as driver_email,
    r.name as office_region
FROM public.shipping_requests sr
JOIN auth.users u1 ON u1.id = sr.user_id
LEFT JOIN public.matched_requests mr ON mr.request_id = sr.id AND mr.status = 'active'
LEFT JOIN public.drivers d ON d.id = mr.driver_id
LEFT JOIN auth.users u2 ON u2.id = d.user_id
LEFT JOIN public.office_assignments oa ON oa.id = sr.office_id
LEFT JOIN public.regions r ON r.id = oa.region_id;

-- Update shipping requests policies
DROP POLICY IF EXISTS "Users can view their own requests and pending requests" ON public.shipping_requests;
CREATE POLICY "Office staff can view relevant requests"
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