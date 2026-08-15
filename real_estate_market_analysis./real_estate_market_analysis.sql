-- Задача 1: Изучение времени активности объявлений квартир в Санкт-Петербурге и Ленинградской области
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдём id объявлений, которые не содержат выбросы, также оставим пропущенные данные:
filtered_id AS(
    SELECT id
    FROM real_estate.flats
    WHERE
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
-- Определяем категории и фильтруем объявления:
orders_category AS (
    SELECT 
        *,
        CASE
	        WHEN a.days_exposition <= 30 THEN '1-30 days'
	        WHEN a.days_exposition <= 90 THEN '31-90 days'
	        WHEN a.days_exposition <= 180 THEN '91-180 days'
	        WHEN a.days_exposition > 180 THEN '181+ days'
	        WHEN a.days_exposition IS NULL THEN 'non category'
        END AS days_exposition_category,
        CASE
      		WHEN c.city != 'Санкт-Петербург' THEN 'Ленинградская область'
      		ELSE 'Санкт-Петербург'
        END AS region
	FROM real_estate.flats f 
	JOIN real_estate.advertisement a USING (id)
	JOIN real_estate.city c USING (city_id)
	JOIN real_estate.type t USING(type_id)
	WHERE id IN (SELECT * FROM filtered_id)
        AND DATE_TRUNC('year', a.first_day_exposition)>='2015-01-01' 
        AND DATE_TRUNC('year', a.first_day_exposition)<'2019-01-01'    
        AND a.days_exposition IS NOT NULL
        AND t.type='город'
),
-- Два СТЕ для определения количества отфильтрованных объявлений в разрезе регионов:
filtrid_advertisement_count_spb AS (SELECT COUNT(id) AS id_count FROM orders_category WHERE region='Санкт-Петербург'),
filtrid_advertisement_count_lr AS (SELECT COUNT(id) AS id_count FROM orders_category WHERE region='Ленинградская область'),
-- Выводим данные по Санкт-Петербургу:
spb_stats AS (
    SELECT 
    	region, 
    	days_exposition_category, 
        COUNT(id) AS count_advertisement,
        ROUND(COUNT(id)::numeric/(SELECT id_count FROM filtrid_advertisement_count_spb), 2) AS perc_advertisement_region,
        ROUND((AVG(last_price)/AVG(total_area))::NUMERIC, 2)  AS avg_price_1sm, 
        ROUND(AVG(total_area)::numeric, 2) AS avg_total_area,
        ROUND(AVG(last_price)::numeric, 2) AS avg_last_price,
        PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY rooms) AS rooms_median,
        PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY balcony) AS balcony_median,
        PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY floor) AS floor_median
	FROM orders_category
	GROUP BY region, days_exposition_category
	HAVING region='Санкт-Петербург'
	ORDER BY days_exposition_category
),
-- Выводим данные для Ленинградской области:
lr_stats AS (
	SELECT 
		region, 
		days_exposition_category, 
        COUNT(id) AS count_advertisement, 
        ROUND(COUNT(id)::numeric/(SELECT id_count FROM filtrid_advertisement_count_lr), 2) AS perc_advertisement_region,
        ROUND((AVG(last_price)/AVG(total_area))::NUMERIC, 2) AS avg_price_1sm, 
        ROUND(AVG(total_area)::numeric, 2) AS avg_total_area,
        ROUND(AVG(last_price)::numeric, 2) AS avg_last_price,
        PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY rooms) AS rooms_median,
        PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY balcony) AS balcony_median,
        PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY floor) AS floor_median
	FROM orders_category
	GROUP BY region, days_exposition_category
	HAVING region='Ленинградская область'
	ORDER BY days_exposition_category
)
-- Обединяем данные в итговом запросе:
SELECT 
	region, 
	days_exposition_category, 
	count_advertisement, 
	perc_advertisement_region, 
	avg_price_1sm, 
	avg_total_area, 
	avg_last_price, 
	rooms_median, balcony_median, 
	floor_median
FROM spb_stats
UNION ALL
SELECT 
	region, 
	days_exposition_category, 
	count_advertisement, 
	perc_advertisement_region, 
	avg_price_1sm, 
	avg_total_area, 
	avg_last_price, 
	rooms_median, 
	balcony_median, 
	floor_median
FROM lr_stats;



-- Задача 2: Определение сезонных изменений на рынке недвижимости в Санкт-Петербурге и Ленинградской области
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдём id объявлений, которые не содержат выбросы, также оставим пропущенные данные:
filtered_id AS(
    SELECT id
    FROM real_estate.flats
    WHERE
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
        AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
-- Находим день снятия объявления и фильтруем данные:
filtred_stats AS (
	SELECT 
		*, 
		(a.first_day_exposition + '1 day'::INTERVAL*a.days_exposition) AS last_day_exposition
	FROM real_estate.flats f
	JOIN real_estate.advertisement a USING(id)
	JOIN real_estate.type t USING(type_id)
	WHERE 
		id IN (SELECT * FROM filtered_id)
        AND DATE_TRUNC('year', a.first_day_exposition)>='2015-01-01' 
        AND DATE_TRUNC('year', a.first_day_exposition)<'2019-01-01' 
        AND a.days_exposition IS NOT NULL
        AND t.type='город'
),
-- Выделяем месяц публикации и снятия объявлений
filtred_stats_month AS (
	SELECT 
		*, 
		EXTRACT(MONTH FROM first_day_exposition) AS fd_month, 
        EXTRACT(MONTH FROM last_day_exposition) AS ld_month
    FROM filtred_stats
),
-- Проводим агрегацию по месяцам публикации объявлений:                        
fd_exposition_stats_month AS (
	SELECT 
	    fd_month AS month_exposition,
        COUNT(id) AS count_advertisement,
        ROUND((AVG(last_price)/AVG(total_area))::NUMERIC, 2) AS avg_price_1sm,
        ROUND(AVG(total_area)::numeric, 2) AS avg_total_area
    FROM filtred_stats_month
	GROUP BY fd_month
	ORDER BY month_exposition
),
-- Проводим агрегацию по месяцам снятия объявлений:
ld_exposition_stats_month AS (
    SELECT 
    	ld_month AS month_exposition,
    	COUNT(id) AS count_advertisement,
    	ROUND((AVG(last_price)/AVG(total_area))::NUMERIC, 2) AS avg_price_1sm,
    	ROUND(AVG(total_area)::numeric, 2) AS avg_total_area
    FROM filtred_stats_month
    GROUP BY ld_month
    ORDER BY month_exposition
)
-- Выводим итоговый результат и добавляем ранжирование по количеству объявлений:
SELECT 
    'Месяц публикации объявления' AS status, 
    month_exposition, 
    count_advertisement, 
    DENSE_RANK() OVER(ORDER BY count_advertisement DESC) AS count_advertisement_rank, 
    avg_price_1sm, 
    avg_total_area
FROM fd_exposition_stats_month
UNION ALL
SELECT 
	'Месяц снятия объявления' AS status, month_exposition, 
	count_advertisement, 
	DENSE_RANK() OVER(ORDER BY count_advertisement DESC) AS count_advertisement_rank, 
	avg_price_1sm, 
	avg_total_area
FROM ld_exposition_stats_month;
