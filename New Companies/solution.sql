-- Intended to work on ORACLE DB or compatily db
SELECT
    c.company_code,
    c.founder,
    COUNT(DISTINCT lead_manager_code),
    COUNT(DISTINCT senior_manager_code),
    COUNT(DISTINCT manager_code),
    COUNT(DISTINCT employee_code)
FROM 
    Company c
LEFT JOIN 
    Employee e
    ON c.company_code = e.company_code
GROUP BY 
    c.company_code, c.founder
ORDER BY 
    c.company_code;
