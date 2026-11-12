/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: Владимиров Денис	
 * Дата: 31.08.2026
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:
-- Напишите ваш запрос здесь

SELECT 
    COUNT(*) AS total_users,
    SUM(payer) AS total_payers,
    ROUND(SUM(payer)::numeric / COUNT(*) * 100, 2) AS fraction_payers
FROM 
    fantasy.users;
	


-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
-- Напишите ваш запрос здесь

SELECT 
    r.race, 
    SUM(u.payer) AS total_payers,
    COUNT(*) AS total_users,
    ROUND(SUM(u.payer)::numeric / COUNT(*) * 100, 2) AS payers_share
FROM 
    fantasy.users AS u
LEFT JOIN 
    fantasy.race AS r ON u.race_id = r.race_id
GROUP BY 
    r.race
ORDER BY payers_share DESC;


-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
-- Напишите ваш запрос здесь

SELECT 
    COUNT(amount) AS total_purchases_count,
    SUM(amount) AS total_purchases_amount,
    MIN(amount) AS min_amount,
    MAX(amount) AS max_amount,
    ROUND(AVG(amount)::numeric, 2) AS avg_amount,
    PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY amount) AS median_amount,
    ROUND(STDDEV(amount)::numeric, 2) AS stddev_amount
FROM 
    fantasy.events;

-- 2.2: Аномальные нулевые покупки:
-- Напишите ваш запрос здесь

SELECT 
    SUM(CASE WHEN amount = 0 THEN 1 ELSE 0 END) AS zero_amount_count,
    COUNT(*) AS total_count,
    ROUND(SUM(CASE WHEN amount = 0 THEN 1 ELSE 0 END)::numeric / COUNT(*) * 100, 2) AS zero_amount_share
FROM 
    fantasy.events;

-- 2.3: Популярные эпические предметы:
-- Напишите ваш запрос здесь

WITH filtered_events AS (
    SELECT 
        item_code,
        id
    FROM 
        fantasy.events
    WHERE 
        amount > 0
),
total_metrics AS (
    SELECT 
        COUNT(*) AS total_sales,
        COUNT(DISTINCT id) AS total_buyers
    FROM 
        filtered_events
)
SELECT 
    i.game_items,
    COUNT(*) AS item_sales_count,
    ROUND(COUNT(*)::numeric / tm.total_sales * 100, 2) AS sales_share,
    ROUND(COUNT(DISTINCT fe.id)::numeric / tm.total_buyers * 100, 2) AS buyers_share
FROM 
    filtered_events AS fe
JOIN 
    total_metrics AS tm ON 1 = 1
JOIN 
	fantasy.items i ON i.item_code = fe.item_code 
GROUP BY 
    i.game_items, 
    tm.total_sales, 
    tm.total_buyers
ORDER BY
    item_sales_count DESC,
	buyers_share DESC;

-- Часть 2. Решение ad hoc-задачbи
-- Задача: Зависимость активности игроков от расы персонажа:

WITH 
race_users AS (
    SELECT 
        race_id,
        COUNT(id) AS total_users
    FROM 
        fantasy.users
    GROUP BY 
        race_id
),
buyer_users AS (
    SELECT DISTINCT
        u.race_id,
        u.id,
        u.payer
    FROM 
        fantasy.users AS u
    INNER JOIN 
        fantasy.events AS e ON u.id = e.id
    WHERE 
        e.amount > 0
),
race_buyers AS (
    SELECT 
        bu.race_id,
        COUNT(DISTINCT bu.id) AS total_buyers,
        ROUND(
            SUM(CASE WHEN bu.payer = 1 THEN 1 ELSE 0 END)::numeric 
            / COUNT(DISTINCT bu.id) * 100, 
            2
        ) AS payers_share_from_buyers
    FROM 
        buyer_users AS bu
    GROUP BY 
        bu.race_id
),
buyer_events AS (
    SELECT 
        u.race_id,
        COUNT(e.amount) AS total_purchases_count,
        SUM(e.amount) AS total_purchases_sum
    FROM 
        fantasy.events AS e
    INNER JOIN 
        fantasy.users AS u ON e.id = u.id
    WHERE 
        e.amount > 0
    GROUP BY 
        u.race_id
)
SELECT 
	r.race,
    ru.total_users,
    COALESCE(rb.total_buyers, 0) AS total_buyers,
    ROUND(COALESCE(rb.total_buyers, 0)::numeric / ru.total_users * 100, 2) AS buyers_share,
    COALESCE(rb.payers_share_from_buyers, 0) AS payers_share_from_buyers,
    ROUND(be.total_purchases_count::numeric / rb.total_buyers, 2) AS avg_purchases_per_buyer,
    ROUND(be.total_purchases_sum::numeric / be.total_purchases_count, 2) AS avg_purchase_cost,
    ROUND(be.total_purchases_sum::numeric / rb.total_buyers, 2) AS avg_total_sum_per_buyer
FROM 
    race_users AS ru
LEFT JOIN 
    race_buyers AS rb ON ru.race_id = rb.race_id
LEFT JOIN 
    buyer_events AS be ON ru.race_id = be.race_id
JOIN 
	fantasy.race r ON r.race_id  = ru.race_id  
ORDER BY 
    ru.race_id;
