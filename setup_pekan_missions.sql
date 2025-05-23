-- Insert location missions for Pekan
INSERT INTO public.location_missions (location_name, title, description, mission_type, points, questions, requirements)
VALUES
  ('Sultan Abu Bakar Museum', 'The Museum Guardian', 'Find Pak Ahmad, the museum''s long-time guardian. He has fascinating stories about the royal artifacts.', 'interactive', 100,
   '[
     {
       "question": "According to Pak Ahmad, which Sultan established this museum?",
       "options": ["Sultan Abu Bakar", "Sultan Ahmad Shah", "Sultan Abdullah", "Sultan Iskandar"],
       "correct_answer": "Sultan Abu Bakar"
     },
     {
       "question": "What year was the museum building originally constructed?",
       "options": ["1888", "1929", "1950", "1976"],
       "correct_answer": "1929"
     },
     {
       "question": "What was this building''s original purpose?",
       "options": ["Royal Palace", "Government Office", "School", "Hospital"],
       "correct_answer": "Government Office"
     }
   ]',
   '[
     {
       "type": "find_person",
       "description": "Find Pak Ahmad near the main entrance. He wears a traditional Malay outfit and a songkok.",
       "validation": "verbal_confirmation"
     }
   ]'),
  
  ('Masjid Sultan Abdullah', 'The Mosque''s Keeper', 'Meet Pak Imam, who will share the mosque''s architectural and spiritual significance.', 'interactive', 100,
   '[
     {
       "question": "In which year was Masjid Sultan Abdullah completed?",
       "options": ["1920", "1932", "1945", "1950"],
       "correct_answer": "1932"
     },
     {
       "question": "What architectural style is prominently featured in the mosque?",
       "options": ["Modern", "Colonial", "Indo-Saracenic", "Gothic"],
       "correct_answer": "Colonial"
     },
     {
       "question": "Which Sultan commissioned the building of this mosque?",
       "options": ["Sultan Abu Bakar", "Sultan Abdullah", "Sultan Ahmad Shah", "Sultan Iskandar"],
       "correct_answer": "Sultan Abdullah"
     }
   ]',
   '[
     {
       "type": "find_person",
       "description": "Find Pak Imam near the prayer hall. He will be wearing white robes.",
       "validation": "verbal_confirmation"
     }
   ]'),
  
  ('Pekan Riverfront', 'The River Tales', 'Look for Pak Man, a local fisherman who knows all about the river''s history and its importance to Pekan.', 'interactive', 100,
   '[
     {
       "question": "What is the name of the major river that flows through Pekan?",
       "options": ["Pahang River", "Pekan River", "Kuantan River", "Rompin River"],
       "correct_answer": "Pahang River"
     },
     {
       "question": "What was the historical significance of Pekan Riverfront?",
       "options": ["Royal Port", "Trading Hub", "Fishing Village", "Military Base"],
       "correct_answer": "Trading Hub"
     },
     {
       "question": "Which traditional fishing method is still used by local fishermen today?",
       "options": ["Cast Net", "Trawling", "Spearfishing", "Line Fishing"],
       "correct_answer": "Cast Net"
     }
   ]',
   '[
     {
       "type": "find_person",
       "description": "Find Pak Man near the fishing boats. He usually wears a traditional sarong and carries fishing equipment.",
       "validation": "verbal_confirmation"
     }
   ]'),
  
  ('Abu Bakar Palace', 'The Palace Chronicles', 'Seek out Pak Zul, a palace historian who can tell you about the royal residence''s past.', 'interactive', 100,
   '[
     {
       "question": "What is the other name for Abu Bakar Palace?",
       "options": ["Istana Mangga Tunggal", "Istana Pekan", "Istana Mahkota", "Istana Pahang"],
       "correct_answer": "Istana Mangga Tunggal"
     },
     {
       "question": "When was the palace completed?",
       "options": ["1888", "1899", "1929", "1950"],
       "correct_answer": "1929"
     },
     {
       "question": "What architectural style is the palace built in?",
       "options": ["Neo-Classical", "Gothic", "Malay Traditional", "Art Deco"],
       "correct_answer": "Neo-Classical"
     }
   ]',
   '[
     {
       "type": "find_person",
       "description": "Find Pak Zul near the palace gardens. He wears a formal Malay attire with a name tag.",
       "validation": "verbal_confirmation"
     }
   ]');

-- Create mission requirements template
INSERT INTO public.mission_requirements (mission_id, requirement_type, description, validation_rules, sequence_number)
SELECT 
  m.id,
  'find_person',
  CASE 
    WHEN m.location_id IN (SELECT id FROM quest_locations WHERE name = 'Sultan Abu Bakar Museum') THEN 'Find Pak Ahmad near the main entrance'
    WHEN m.location_id IN (SELECT id FROM quest_locations WHERE name = 'Masjid Sultan Abdullah') THEN 'Find Pak Imam near the prayer hall'
    WHEN m.location_id IN (SELECT id FROM quest_locations WHERE name = 'Pekan Riverfront') THEN 'Find Pak Man near the fishing boats'
    WHEN m.location_id IN (SELECT id FROM quest_locations WHERE name = 'Abu Bakar Palace') THEN 'Find Pak Zul near the palace gardens'
  END,
  jsonb_build_object(
    'type', 'verbal_confirmation',
    'required_keywords', ARRAY['history', 'guide', 'story']
  ),
  1
FROM missions m
WHERE m.mission_type = 'interactive';

-- Create mission questions template
INSERT INTO public.mission_questions (mission_id, question, question_type, correct_answer, options, points, sequence_number)
SELECT 
  m.id,
  q->>'question',
  'multiple_choice',
  q->>'correct_answer',
  q->'options',
  CASE sequence_number
    WHEN 1 THEN 40
    WHEN 2 THEN 30
    WHEN 3 THEN 30
  END,
  sequence_number
FROM missions m
CROSS JOIN LATERAL jsonb_array_elements(
  (SELECT questions FROM location_missions WHERE location_name = (
    SELECT name FROM quest_locations WHERE id = m.location_id
  ))
) WITH ORDINALITY AS t(q, sequence_number)
WHERE m.mission_type = 'interactive';

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_mission_questions_sequence ON public.mission_questions (mission_id, sequence_number);
CREATE INDEX IF NOT EXISTS idx_mission_requirements_sequence ON public.mission_requirements (mission_id, sequence_number); 