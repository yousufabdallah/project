-- Create driver permissions table
CREATE TABLE IF NOT EXISTS public.driver_permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) NOT NULL,
    is_approved BOOLEAN DEFAULT false,
    approved_by UUID REFERENCES auth.users(id),
    approved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(user_id)
);

-- Enable RLS
ALTER TABLE public.driver_permissions ENABLE ROW LEVEL SECURITY;

-- Create policies for driver_permissions
CREATE POLICY "Users can view their own driver permission"
    ON public.driver_permissions
    FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY "Admins can manage driver permissions"
    ON public.driver_permissions
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM auth.users
            WHERE id = auth.uid()
            AND (raw_user_meta_data->>'is_admin')::boolean = true
        )
    );

-- Update drivers policies to check for approval
DROP POLICY IF EXISTS "Users can create their own driver profile" ON public.drivers;
CREATE POLICY "Approved users can create their own driver profile"
    ON public.drivers
    FOR INSERT
    TO authenticated
    WITH CHECK (
        auth.uid() = user_id
        AND EXISTS (
            SELECT 1 FROM public.driver_permissions
            WHERE user_id = auth.uid()
            AND is_approved = true
        )
    );

-- Grant permissions
GRANT ALL ON public.driver_permissions TO authenticated;