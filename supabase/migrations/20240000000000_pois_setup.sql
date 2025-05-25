-- Create enum for facility types
CREATE TYPE facility_type AS ENUM (
    'toilets',
    'parking',
    'wifi',
    'food',
    'accessible'
);

-- Create points of interest table
CREATE TABLE points_of_interest (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    opening_time TIME,
    closing_time TIME,
    crowd_density VARCHAR(50),
    ticket_price_adult DECIMAL(10,2),
    ticket_price_child DECIMAL(10,2),
    best_time_to_visit TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create facilities junction table
CREATE TABLE poi_facilities (
    poi_id UUID REFERENCES points_of_interest(id) ON DELETE CASCADE,
    facility facility_type NOT NULL,
    PRIMARY KEY (poi_id, facility)
);

-- Create community content table
CREATE TABLE community_content (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    poi_id UUID REFERENCES points_of_interest(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    content_type VARCHAR(50) NOT NULL,
    storage_path TEXT NOT NULL,
    caption TEXT,
    likes_count INTEGER DEFAULT 0,
    username VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create likes table for community content
CREATE TABLE content_likes (
    content_id UUID REFERENCES community_content(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    PRIMARY KEY (content_id, user_id)
);

-- Clear existing data
DELETE FROM poi_facilities;
DELETE FROM points_of_interest;

-- Insert POIs for Pekan
INSERT INTO points_of_interest (
    name,
    description,
    latitude,
    longitude,
    opening_time,
    closing_time,
    crowd_density,
    ticket_price_adult,
    ticket_price_child,
    best_time_to_visit
) VALUES 
(
    'Sultan Abu Bakar Museum',
    'A majestic museum showcasing the royal heritage of Pekan. Built in 1929, this museum was originally a royal palace.',
    3.493542,
    103.390350,
    '09:00',
    '17:00',
    'Moderate',
    10.00,
    5.00,
    'Early morning or late afternoon to avoid crowds'
),
(
    'Masjid Sultan Abdullah',
    'A historic mosque built in 1932, featuring beautiful Islamic architecture and spiritual significance.',
    3.495233,
    103.389090,
    '05:00',
    '22:00',
    'Low',
    0.00,
    0.00,
    'During prayer times for authentic experience'
),
(
    'Pekan Riverfront',
    'A scenic waterfront along the Pahang River, perfect for experiencing local life and cuisine.',
    3.491516,
    103.397449,
    '00:00',
    '23:59',
    'High during evenings',
    0.00,
    0.00,
    'Evening for the best atmosphere and local food stalls'
),
(
    'Abu Bakar Palace',
    'A majestic palace that serves as a testament to Pekan\'s royal heritage and architectural beauty.',
    3.485188,
    103.381302,
    '09:00',
    '16:00',
    'Low',
    15.00,
    7.50,
    'Morning for the best lighting conditions'
);

-- Insert facilities for all POIs
INSERT INTO poi_facilities (poi_id, facility)
SELECT 
    id,
    unnest(ARRAY['toilets', 'parking', 'wifi']::facility_type[])
FROM points_of_interest
WHERE name IN ('Sultan Abu Bakar Museum', 'Abu Bakar Palace');

INSERT INTO poi_facilities (poi_id, facility)
SELECT 
    id,
    unnest(ARRAY['toilets', 'parking']::facility_type[])
FROM points_of_interest
WHERE name = 'Masjid Sultan Abdullah';

INSERT INTO poi_facilities (poi_id, facility)
SELECT 
    id,
    unnest(ARRAY['food', 'parking']::facility_type[])
FROM points_of_interest
WHERE name = 'Pekan Riverfront';

-- Create RLS policies
ALTER TABLE points_of_interest ENABLE ROW LEVEL SECURITY;
ALTER TABLE poi_facilities ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_content ENABLE ROW LEVEL SECURITY;
ALTER TABLE content_likes ENABLE ROW LEVEL SECURITY;

-- Create policies for public read access
CREATE POLICY "Allow public read access on POIs" ON points_of_interest
    FOR SELECT USING (true);

CREATE POLICY "Allow public read access on facilities" ON poi_facilities
    FOR SELECT USING (true);

CREATE POLICY "Allow public read access on community content" ON community_content
    FOR SELECT USING (true);

-- Create policy for authenticated users to create content
CREATE POLICY "Allow authenticated users to create content" ON community_content
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Create policy for users to like content
CREATE POLICY "Allow authenticated users to like content" ON content_likes
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Create function to handle likes
CREATE OR REPLACE FUNCTION handle_content_like()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE community_content
        SET likes_count = likes_count + 1
        WHERE id = NEW.content_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE community_content
        SET likes_count = likes_count - 1
        WHERE id = OLD.content_id;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for likes
CREATE TRIGGER content_likes_trigger
AFTER INSERT OR DELETE ON content_likes
FOR EACH ROW EXECUTE FUNCTION handle_content_like(); 