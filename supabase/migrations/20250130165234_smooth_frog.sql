-- Add unique constraint to ensure only one active driver per user
ALTER TABLE public.drivers
ADD CONSTRAINT unique_active_driver_per_user UNIQUE (user_id, status)
WHERE status = 'active';

-- Create function to handle driver status changes
CREATE OR REPLACE FUNCTION handle_driver_status()
RETURNS TRIGGER AS $$
BEGIN
    -- If the new record is active, deactivate all other drivers for this user
    IF NEW.status = 'active' THEN
        UPDATE public.drivers
        SET status = 'inactive'
        WHERE user_id = NEW.user_id
        AND id != NEW.id
        AND status = 'active';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to manage driver status
DROP TRIGGER IF EXISTS manage_driver_status ON public.drivers;
CREATE TRIGGER manage_driver_status
    BEFORE INSERT OR UPDATE OF status
    ON public.drivers
    FOR EACH ROW
    EXECUTE FUNCTION handle_driver_status();

-- Add index for faster status queries
CREATE INDEX IF NOT EXISTS idx_drivers_status ON public.drivers(status);