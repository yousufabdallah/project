-- Create driver survey table
CREATE TABLE IF NOT EXISTS public.driver_surveys (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) NOT NULL,
    full_name TEXT NOT NULL,
    tribe TEXT NOT NULL,
    age INTEGER NOT NULL,
    car_type TEXT NOT NULL,
    civil_id TEXT NOT NULL,
    phone_number TEXT NOT NULL,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(user_id)
);

-- Enable RLS
ALTER TABLE public.driver_surveys ENABLE ROW LEVEL SECURITY;

-- Create policies for driver surveys
CREATE POLICY "Users can create their own survey"
    ON public.driver_surveys
    FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can view their own survey"
    ON public.driver_surveys
    FOR SELECT
    TO authenticated
    USING (
        auth.uid() = user_id
        OR 
        EXISTS (
            SELECT 1 FROM public.user_roles
            WHERE id = auth.uid() AND is_admin = true
        )
    );

-- Create view for driver surveys with user information
CREATE OR REPLACE VIEW public.driver_surveys_view AS
SELECT 
    ds.*,
    u.email as user_email
FROM public.driver_surveys ds
JOIN auth.users u ON u.id = ds.user_id;

-- Grant necessary permissions
GRANT ALL ON public.driver_surveys TO authenticated;
GRANT SELECT ON public.driver_surveys_view TO authenticated;