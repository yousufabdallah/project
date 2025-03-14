-- First, backup existing data
CREATE TABLE IF NOT EXISTS shipping_requests_backup AS
SELECT * FROM public.shipping_requests;

-- Drop existing policies that depend on the status column
DROP POLICY IF EXISTS "Users can view their own requests and pending requests" ON public.shipping_requests;
DROP POLICY IF EXISTS "Update shipping request status" ON public.shipping_requests;

-- Drop view that depends on the status column
DROP VIEW IF EXISTS public.shipping_requests_with_users;

-- Create enum type for shipping request status
CREATE TYPE public.shipping_status AS ENUM (
    'pending',      -- في انتظار سائق
    'in_progress',  -- في الطريق
    'delivered',    -- تم التسليم
    'cancelled'     -- ملغي
);

-- Add temporary column with new type
ALTER TABLE public.shipping_requests 
    ADD COLUMN status_new shipping_status;

-- Update the new column based on existing status
UPDATE public.shipping_requests
SET status_new = CASE 
    WHEN status = 'pending' THEN 'pending'::shipping_status
    WHEN status = 'in_progress' THEN 'in_progress'::shipping_status
    WHEN status = 'delivered' THEN 'delivered'::shipping_status
    WHEN status = 'cancelled' THEN 'cancelled'::shipping_status
    ELSE 'pending'::shipping_status
END;

-- Drop old status column
ALTER TABLE public.shipping_requests DROP COLUMN status CASCADE;

-- Rename new column
ALTER TABLE public.shipping_requests RENAME COLUMN status_new TO status;

-- Set default and not null constraints
ALTER TABLE public.shipping_requests 
    ALTER COLUMN status SET DEFAULT 'pending'::shipping_status,
    ALTER COLUMN status SET NOT NULL;

-- Recreate the view
CREATE OR REPLACE VIEW public.shipping_requests_with_users AS
SELECT 
    sr.id,
    sr.user_id,
    sr.pickup_location,
    sr.delivery_location,
    sr.description,
    sr.image_url,
    sr.status::text,
    sr.created_at,
    sr.updated_at,
    auth.get_user_email(sr.user_id) as user_email,
    auth.get_user_email(d.user_id) as driver_email
FROM public.shipping_requests sr
LEFT JOIN public.matched_requests mr ON mr.request_id = sr.id AND mr.status = 'active'
LEFT JOIN public.drivers d ON d.id = mr.driver_id;

-- Enable RLS on the view
ALTER VIEW public.shipping_requests_with_users SET (security_invoker = true);

-- Recreate policies
CREATE POLICY "Users can view their own requests and pending requests"
    ON public.shipping_requests
    FOR SELECT
    TO authenticated
    USING (
        auth.uid() = user_id 
        OR 
        status = 'pending'
    );

-- Create policy for updating shipping request status
CREATE POLICY "Update shipping request status"
    ON public.shipping_requests
    FOR UPDATE
    TO authenticated
    USING (
        -- User owns the request
        auth.uid() = user_id
        OR
        -- Driver is assigned to the request
        EXISTS (
            SELECT 1 FROM public.matched_requests mr
            JOIN public.drivers d ON d.id = mr.driver_id
            WHERE mr.request_id = shipping_requests.id
            AND d.user_id = auth.uid()
        )
        OR
        -- User is admin
        EXISTS (
            SELECT 1 FROM public.user_roles
            WHERE id = auth.uid() AND is_admin = true
        )
    )
    WITH CHECK (
        -- User owns the request
        auth.uid() = user_id
        OR
        -- Driver is assigned to the request
        EXISTS (
            SELECT 1 FROM public.matched_requests mr
            JOIN public.drivers d ON d.id = mr.driver_id
            WHERE mr.request_id = shipping_requests.id
            AND d.user_id = auth.uid()
        )
        OR
        -- User is admin
        EXISTS (
            SELECT 1 FROM public.user_roles
            WHERE id = auth.uid() AND is_admin = true
        )
    );