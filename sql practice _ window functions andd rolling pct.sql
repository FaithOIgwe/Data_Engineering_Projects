/* SQL Practice */


CREATE TEMP TABLE loan_applications (
    application_id VARCHAR(10),
    customer_id VARCHAR(10),
    channel VARCHAR(20),
    application_date DATE,
    requested_amount NUMERIC,
    offered_amount NUMERIC,
    status VARCHAR(30)
);

INSERT INTO loan_applications VALUES
    ('A001', 'C001', 'organic',  '2026-08-01',  5000,  5000, 'DISBURSED'),
    ('A002', 'C002', 'organic',  '2026-08-01', 10000,  7000, 'OFFER_SELECTED'),
    ('A003', 'C003', 'partner',  '2026-08-02',  3000,  NULL, 'DECLINED'),
    ('A004', 'C004', 'referral', '2026-08-02', 20000, 15000, 'DISBURSED'),
    ('A005', 'C001', 'partner',  '2026-08-03',  8000,  6000, 'DISBURSED'),
    ('A006', 'C005', 'organic',  '2026-08-03',  4000,  NULL, 'DECLINED'),
    ('A007', 'C006', 'partner',  '2026-08-04', 50000, 30000, 'OFFER_SELECTED'),
    ('A008', 'C007', 'referral', '2026-08-04',  2500,  2000, 'DISBURSED'),
    ('A009', 'C008', 'organic',  '2026-08-05', 12000, 10000, 'DISBURSED'),
    ('A010', 'C003', 'partner',  '2026-08-05',  6000,  5000, 'OFFER_SELECTED'),
    ('A011', NULL,   'organic',  '2026-08-06',  7000,  5000, 'OFFER_SELECTED'),
    ('A012', 'C009', NULL,       '2026-08-06', 15000, 12000, 'DISBURSED');
	
	/* Viewing the table*/
	
	SELECT *
FROM loan_applications;

/* Daily running total 
Daily running total

Return:
Application date
Applications submitted that day
Running total of applications*/
select  application_date, count(application_id) as daily_spplications,
	Sum(COUNT(application_id)) over (order by application_date) as running_total
	from loan_applications
	group by application_date
	order by application_date
	
	
/* For every channel, return its:

Application count
Percentage contribution to all applications
Disbursement count
Percentage contribution to all disbursements

The contribution percentages across all channels should add up to 100%.*/
SELECT * FROM loan_applications

SELECT
    COALESCE(channel, 'unknown') AS channel,
    COUNT(*) AS application_count,

    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        2
    ) AS application_contribution_pct,

    COUNT(*) FILTER (
        WHERE status = 'DISBURSED'
    ) AS disbursement_count,

    ROUND(
        100.0 * COUNT(*) FILTER (WHERE status = 'DISBURSED')
        / NULLIF(
            SUM(COUNT(*) FILTER (WHERE status = 'DISBURSED')) OVER (),
            0
        ),
        2
    ) AS disbursement_contribution_pct

FROM loan_applications
GROUP BY COALESCE(channel, 'unknown')
ORDER BY application_count DESC;