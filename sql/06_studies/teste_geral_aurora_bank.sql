
SELECT 
    table_schema,
    table_name,
    table_type
FROM information_schema.tables
WHERE table_schema IN ('bronze', 'silver', 'sdx', 'gold', 'meta')
ORDER BY table_schema, table_name;