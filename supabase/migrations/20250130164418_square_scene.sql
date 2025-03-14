/*
  # Add indexes and create drivers view

  1. Changes
    - Add performance indexes for foreign keys
    - Create view for drivers with user information
    - Grant necessary permissions

  2. Security
    - View inherits RLS from underlying tables
*/

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_drivers_user_id ON public.drivers(user_id);
CREATE INDEX IF NOT EXISTS idx_shipping_requests_user_id ON public.shipping_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_matched_requests_driver_id ON public.matched_requests(driver_id);
CREATE INDEX IF NOT EXISTS idx_matched_requests_request_id ON public.matched_requests(request_id);

-- Create view for drivers with user information
CREATE OR REPLACE VIEW public.drivers_with_users AS
SELECT 
    d.*,
    u.email as user_email
FROM public.drivers d
JOIN auth.users u ON u.id = d.user_id;

-- Grant necessary permissions
GRANT SELECT ON public.drivers_with_users TO authenticated;