-- 1) What is the total amount each customer spent at the restaurant?
--Total Spend
SELECT S.customer_id
		,SUM(M.price) as total_spend
FROM dbo.sales S
LEFT JOIN dbo.menu M
ON S.product_id = M.product_id
GROUP BY S.customer_ID

--2) How many days has each customer visited the restaurant?
SELECT customer_id
	,COUNT(DISTINCT order_date) AS [Number of Visits]
FROM [dbo].[sales]
GROUP BY customer_id

--3) What was the first item from the menu purchased by each customer?
WITH Sub AS
(
	SELECT S.customer_id
		,S.product_id
		,M.product_name
		,Item = DENSE_RANK() OVER (PARTITION BY S.customer_id ORDER BY s.order_date)
	FROM [dbo].[sales] S
	LEFT JOIN [dbo].[menu] M
	ON S.product_id = M.product_id
)
SELECT Sub.customer_id
		,Sub.product_name
FROM Sub
WHERE Item = 1
GROUP BY Sub.customer_id
		,Sub.product_name
--4) What is the most purchased item on the menu and how many times was it purchased by all customers?

WITH T as 
(
	SELECT COUNT(S.product_id) AS count_of_product
			,M.product_name
			,DENSE_RANK() OVER (ORDER BY COUNT(S.product_id) DESC) as [Rank]
FROM dbo.sales S
LEFT JOIN dbo.menu M
ON S.product_id = M.product_id
GROUP BY M.product_name
)
SELECT T.count_of_product
	,T.product_name
FROM T
WHERE [Rank] = 1

--5) Which of item was the most popular for each customer

WITH T as 
(
	SELECT	S.customer_id
			,M.product_name
			,COUNT(S.product_id) AS count_of_product
			,DENSE_RANK() OVER (PARTITION BY S.customer_id ORDER BY COUNT(S.product_id) DESC) as [Rank]
FROM dbo.sales S
LEFT JOIN dbo.menu M
ON S.product_id = M.product_id
GROUP BY S.customer_id
		,M.product_name
)

SELECT T.customer_id
		,T.product_name
FROM T
WHERE [Rank] = 1

--6) Which item was purchased first by the customer after they became a member?

WITH [after] as 
(
	SELECT S.customer_id
			,M.Product_Name
			,S.order_date
			,DENSE_RANK() OVER (PARTITION BY S.customer_id ORDER BY S.order_date) as [DR]
	FROM dbo.sales S
	LEFT JOIN dbo.menu M
	ON S.product_id = M.product_id
	LEFT JOIN dbo.members MEM
	ON S.customer_id = MEM.customer_id
	
	WHERE S.order_date > MEM.join_date
)
SELECT [after].customer_id
		,[after].product_name
FROM [after]
WHERE [DR] = 1

--7) Which item was purchased just before the customer became a member?

WITH [before] as 
(
	SELECT S.customer_id
			,M.Product_Name
			,S.order_date
			,DENSE_RANK() OVER (PARTITION BY S.customer_id ORDER BY S.order_date DESC) as [DR]
	FROM dbo.sales S
	LEFT JOIN dbo.menu M
	ON S.product_id = M.product_id
	LEFT JOIN dbo.members MEM
	ON S.customer_id = MEM.customer_id
	
	WHERE S.order_date < MEM.join_date
)
SELECT [before].customer_id
		,[before].product_name
FROM [before]
WHERE [DR] = 1

--8) What is the total items and amount spent for each member before they became a member?

SELECT S.customer_id
		,COUNT(S.product_id) as [Count of Product]
		,SUM(price) as [Total Spend]
FROM dbo.sales S
LEFT JOIN dbo.menu M
ON S.product_id = M.product_id
LEFT JOIN dbo.members MEM
ON S.customer_id = MEM.customer_id
WHERE S.order_date < MEM.join_date
GROUP BY S.customer_id

--9) If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
WITH Spend AS
(
		SELECT S.customer_id
			,M.product_name
			,SUM(price) as [Total Spend]
		FROM dbo.sales S
		LEFT JOIN dbo.menu M
		ON S.product_id = M.product_id
		LEFT JOIN dbo.members MEM
		ON S.customer_id = MEM.customer_id
		GROUP BY S.customer_id
				,M.product_name
),

P AS
(
SELECT Spend.customer_id
		,[Points] = (CASE WHEN Spend.product_name <> 'sushi' THEN (Spend.[Total Spend]*10)
						ELSE ((Spend.[Total Spend]*10)*2)
						END)
FROM Spend
)
SELECT P.customer_id
		,SUM(P.Points) AS Points
FROM P
GROUP BY P.customer_id

-- 10) In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?

WITH Spend AS
(
		SELECT S.customer_id
			,M.product_name
			,S.order_date
			,MEM.join_date
			,DATEADD(day, 6, MEM.join_date) AS [1 Week from Joining]
			,CAST(DATETRUNC(DAY,'2021-01-31') AS DATE) AS [End of Month]
			,SUM(price) as [Total Spend]
		FROM dbo.sales S
		LEFT JOIN dbo.menu M
		ON S.product_id = M.product_id
		LEFT JOIN dbo.members MEM
		ON S.customer_id = MEM.customer_id
		GROUP BY S.customer_id
				,M.product_name
				,S.order_date
				,MEM.join_date
),

P AS
(
SELECT Spend.customer_id
		,[Points] = (CASE WHEN Spend.product_name = 'sushi' THEN ((Spend.[Total Spend]*10)*2)
						WHEN Spend.order_date >= Spend.join_date AND Spend.order_date <= Spend.[1 Week from Joining] THEN ((Spend.[Total Spend]*10)*2)
						ELSE (Spend.[Total Spend]*10)
						END)
FROM Spend
WHERE Spend.order_date <= Spend.[End of Month]
GROUP BY Spend.customer_id
		,Spend.product_name
		,Spend.order_date
		,Spend.join_date
		,Spend.[1 Week from Joining]
		,Spend.[Total Spend]
)

SELECT P.customer_id
		,SUM(P.Points) AS Points
FROM P
WHERE P.customer_id IN ('A','B')
GROUP BY P.customer_id