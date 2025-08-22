-- Changing datatype of column order_date
alter table regsales add clean_order_date datetime;
update regsales set clean_order_date = str_to_date(order_date,'%d-%m-%Y %H:%i');

-- dropping old column 
alter table regsales drop column order_date;
-- Rename column
alter table regsales rename column clean_order_date to order_date  ;

-- Sales & Revenue Analysis
-- 1.	What is the total revenue and total profit generated per year?
select concat_ws(' ',round(sum(revenue)/1e6,2),'M') as total_revenue,
concat_ws(' ',round(sum(profit)/1e6,2),'M') as profit ,year(order_date) as Year
from regsales
group by year(order_date) 
order by sum(revenue) desc;

-- 2.Which are the top 5 customers by total revenue?
select customer_name,concat_ws(' ',round(sum(revenue)/1e6,2),'M') as total_revenue
from regsales
group by customer_name order by sum(revenue) desc
limit 10;

-- 3.Which sales channel (Wholesale, Export, Distributor) generates the highest revenue overall
-- and on average per order?
select channel,round(sum(revenue),2) as overall_revenue,
round(sum(revenue)/count(order_number),2) as Revenue_per_order
from regsales 
group by channel 
order by round(sum(revenue),2) desc;

-- 4.How many unique customers placed orders each year?
select count(distinct customer_name) as unique_customers,year(order_date) as order_year
from regsales
group by order_year;

-- Geographic/Regional Analysis

-- 5. What is the total sales revenue per U.S. state or region ?
select us_region,state_name,round(sum(revenue),2) state_revenue,
round(sum(sum(revenue)) over(partition by us_region),2) as us_region_revenue
from regsales
group by us_region, state_name;
  
-- 6.Compare sales performance across different U.S. regions (e.g., South, West, etc.).
select us_region,round(sum(revenue),2) as total_sales from regsales
group by us_region;

-- Product Insights
-- 7.	What are the top 5 best-selling products by quantity and revenue?
select product_name,sum(quantity) as total_quantity , round(sum(revenue),2) as total_revenue
from regsales 
group by product_name
order by total_revenue desc
limit 5;

-- 8.Compare actual 2017 sales with 2017 budgets for each product.
select product_name,round(sum(revenue)/1e6, 2) as rev_2017,
round(max(budget/1e6),2) as budget_2017,year(order_date) as year_2017
from regsales 
group by product_name, year(order_date) 
having year_2017 = 2017;

select product_name,round(sum(revenue)/1e6, 2) as rev_2017,
max(budget/1e6) as budget_2017
from regsales 
where year(order_date) = 2017
group by product_name;

-- 9.Which product has the highest profit margin (overall and average per unit)?
select product_name,avg(profit_margin_pct) as profit_margin from regsales
group by product_name 
order by profit_margin desc
limit 1;

-- Operational Metrics
-- 10.	What is the average unit price and unit cost per product?
select product_name,cast(avg(unit_price) as decimal(10,2)) as unit_price, 
cast(avg(cost) as decimal(10,2)) as avg_cost_price
from regsales
group by product_name ;

-- 11.How many unique orders placed by each customer each year?
select distinct customer_name,year(order_date) as year ,
count(distinct order_number) as no_of_orders from regsales
group by customer_name ,year;

-- 12.Which state handling the most orders and revenue?
select state_name,count(order_number) as order_count from regsales
group by state_name
order by order_count desc
limit 1;

--  Time Series & Trend Analysis
-- 13.	What is the monthly sales trend over the years?
select order_month_name,round(sum(revenue),2) as total_rev
from regsales group by order_month_name;

-- 14.Which month consistently generates the highest revenue?
select order_month_name,round(sum(revenue),2) as total_rev
from regsales
group by order_month_name
order by total_rev desc
limit 1;

-- 15.What is the year-over-year growth in revenue and profit?

select sales_year,total_revenue,lag(total_revenue) over(order by sales_year) as prev_year_rev,
round((total_revenue-lag(total_revenue) over(order by sales_year))/(nullif(lag(total_revenue) over(order by sales_year),0))*100,2) as rev_pct,
total_profit,lag(total_profit) over(order by sales_year) as prev_yr_profit,
round((total_profit-lag(total_profit) over(order by sales_year))/nullif(lag(total_profit) over(order by sales_year),0)*100,2) as profit_pct
 from
(select year(order_date) as sales_year,round(sum(revenue),2) as total_revenue,
round(sum(profit),2) as total_profit from regsales
group by sales_year) as yearly_data

-- Customer Behavior Insights
-- 16.	Which customers placed repeat orders? How frequently do they order?
select customer_name,count(distinct order_number) as frequency 
from regsales
group by customer_name
having frequency>1
order by frequency desc;

-- 17.Which customers showed the highest increase in spending year-over-year?
with cte_customer as 
(select customer_name,year(order_date) as sales_year,round(sum(revenue),2) as total_spending
from regsales group by customer_name,sales_year) 

select customer_name,sales_year,total_spending,
lag(total_spending) over(partition by customer_name order by sales_year) as prev_yr_sales,
round((total_spending-lag(total_spending) over(partition by customer_name order by sales_year))/
(nullif(lag(total_spending) over(partition by customer_name order by sales_year),0))*100,2) as revenue_growth_pct
from cte_customer ;

 -- 18.What is the average revenue and profit per channel?
 select channel,round(avg(revenue),2) as avg_rev, round(avg(profit),2) as avg_profit
 from regsales
 group by channel;
 
-- Product & Profitability Analysis
-- 19.	Which products are sold most frequently together 
-- (if same order number has multiple products)?
SELECT r1.product_name AS product_1, r2.product_name AS product_2, COUNT(*) AS frequency
FROM regsales r1
JOIN regsales r2
  ON r1.order_number = r2.order_number 
-- to avoid duplicate combinations when joining the same table to itself.
AND r1.product_name < r2.product_name
GROUP BY product_1, product_2
ORDER BY frequency DESC
LIMIT 10;

select r1.product_name as product_1,r2.product_name as product_2,
count(*) as frequency from regsales r1
join regsales r2 on r1.order_number=r2.order_number
-- to avoid duplicate combinations when joining the same table to itself.
and r1.product_name<r2.product_name
group by product_1,product_2
order by frequency desc
limit 10;

-- 20.Are there any products whose actual revenue exceeded budget in 2017?

select product_name,round(max(budget)/1e6,2) as budget_2017, 
round(sum(revenue)/1e6,2) as rev_2017
from regsales
where year(order_date)=2017
group by product_name
having rev_2017>budget_2017;

-- Logistics & Operations
-- 21.	What is the average delivery size per state (in quantity and revenue)?
select state_name,
       round(avg(quantity), 2) as avg_quantity,
       round(avg(revenue), 2) as avg_revenue
from regsales
group by state_name;

-- 22.Which regions consistently receive high-value orders?
select us_region,count(order_number) as order_count,round(avg(revenue),2) as avg_order_value
from regsales
group by us_region
order by avg_order_value desc
