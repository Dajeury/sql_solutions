-- Intended to work on ORACLE DB or compatily db
SELECT *
FROM (
    SELECT NAME, OCCUPATION, 
           ROW_NUMBER() OVER (PARTITION BY OCCUPATION ORDER BY NAME) AS rn
    FROM OCCUPATIONS
)
PIVOT (
    MAX(NAME) FOR OCCUPATION IN ('Doctor' AS Doctor, 'Professor' AS Professor, 'Singer' AS Singer, 'Actor' AS Actor)
)
ORDER BY rn;