use bankingdb;

/* Table Creation */
CREATE TABLE fraudtransactions (
    Transaction_ID     BIGINT PRIMARY KEY AUTO_INCREMENT,
    Customer_ID        BIGINT NOT NULL,
    Account_ID         BIGINT NOT NULL,
    Transaction_Date   DATE NOT NULL,
    Transaction_Time   TIME NOT NULL,
    Amount             DECIMAL(15,2) NOT NULL,
    Transaction_Type   ENUM('Credit', 'Debit') NOT NULL,
    Description        VARCHAR(255),
    Transaction_Mode   ENUM('ATM', 'POS', 'Mobile Banking', 'Internet Banking') NOT NULL,
    Status             ENUM('Completed', 'Failed') NOT NULL,
    Location           VARCHAR(100),

    INDEX (Customer_ID),
    INDEX (Account_ID),
    INDEX (Transaction_Date)
);

/* Data Types of columns in fraudtransactions table */
SELECT COLUMN_NAME, DATA_TYPE 
from Information_schema.columns
where table_name="fraudtransactions" and table_schema="bankingdb";

/* Total number of transactions */
select count(*) as Total_Transactions 
from fraudtransactions;

/* Count of transactions Status */
select Status,count(*) as Total_Transactions 
from fraudtransactions
group by Status
order by Total_Transactions desc; 

/* Total Amount based on type of transaction */
select transaction_type,round(sum(Amount),2) as Total_Amount
from fraudtransactions
group by transaction_type
order by Total_Amount desc;

/* Top 5 customers based on count of transactions */
select customer_id,count(*) as Total_Transactions
from fraudtransactions
group by customer_id
order by Total_Transactions desc
limit 5;

/* Total number of transactions based on location */
select location,count(*) as Total_Transactions
from fraudtransactions
group by location
order by Total_Transactions desc;

/* Total number of transactions and amount based on transaction date  */
select transaction_date,count(*) as Total_Transactions,sum(Amount) as Transaction_Amount
from fraudtransactions
group by transaction_date
order by transaction_date desc;

/* Total number of transactions based on mode of transaction*/
select transaction_mode,count(*) as Total_Transactions
from fraudtransactions
group by transaction_mode
order by Total_Transactions desc;

/* Customer's Available Balance */
select customer_id,
round(sum(case
	when transaction_type="Credit" then amount
    when transaction_type="Debit" then -amount
    else 0
    end),2) as Available_Balance
    from fraudtransactions
    group by customer_id
    order by Available_Balance desc;

/* Transactions of customers's whose transaction amount is greater than avg of transaction amount */
with customer_avg as
(select Customer_ID,round(avg(Amount),2) as Avg_Customer_Amount
	from fraudtransactions
    group by customer_ID)
    
    select * 
    from fraudtransactions t
    join customer_avg c
    on t.customer_id=c.customer_id
    where t.amount > 2*c.Avg_Customer_Amount and transaction_type="Debit";
    
/* Customer with more number of failed transactions */
select DISTINCT Customer_ID, Failed_Transactions
from (
    select Customer_ID,status,
        COUNT(*) OVER (PARTITION BY Customer_ID) AS Failed_Transactions
    FROM fraudtransactions
    WHERE status = 'Failed'
) s
where Failed_Transactions > 2;

/* Transactions at odd hours */
select *
from fraudtransactions
where hour(transaction_time) between 0 and 4 and transaction_type="Debit";

/* Count of transactions that happened in one hour */
with Txns as (
    select *,
           COUNT(*) OVER (PARTITION BY Customer_ID, Transaction_Date, HOUR(Transaction_Time)) AS txn_count
    from fraudtransactions
)
select * 
FROM Txns 
WHERE txn_count > 3;

/* Transactions with description and mode mismatch */
select *
from fraudtransactions
where (description LIKE '%ATM%' AND Transaction_Mode NOT LIKE '%ATM%')
   OR (description LIKE '%Mobile%' AND Transaction_Mode NOT LIKE '%Mobile Banking%')
   OR (description LIKE '%Bill%' AND Transaction_Mode NOT IN ('Internet Banking', 'Mobile Banking','POS'));

/* Transactions of location mismatch of customer in a single day */
With location as (
    select 
        Customer_ID,
        transaction_date,
        transaction_type,
        COUNT(DISTINCT location) as location_count
    from fraudtransactions
    group by Customer_ID, Transaction_Date, transaction_type
    having COUNT(distinct location) > 1
)
select t.*
from fraudtransactions t
join location l
ON t.Customer_ID = l.Customer_ID AND t.transaction_Date = l.transaction_Date
order by Customer_ID;