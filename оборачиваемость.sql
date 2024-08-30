-- Заполнение таблицы остаткоми на дату за весь период
DECLARE
    v_date DATE := TO_DATE('2024-08-21', 'YYYY-MM-DD');
    v_end_date DATE := TO_DATE('2024-08-28', 'YYYY-MM-DD');
BEGIN
    WHILE v_date <= v_end_date LOOP
        remains.calc(v_date, true, 23, 2, false);
        v_date := v_date + 1; -- Переход к следующей дате
    END LOOP;
END ;



-- Рсчет суммы остатков за период и остатка на конец периода

WITH Remains AS (
    SELECT
        t.article,
        t.STORELOC,
        t.QUANTITY,
        SUM(t.QUANTITY) OVER (PARTITION BY t.article, t.STORELOC) AS Сумма_остатков_периода,
        t.remdate,
        FIRST_VALUE(t.QUANTITY) OVER (PARTITION BY t.article, t.STORELOC ORDER BY t.remdate DESC) AS Quantity_Max_Remdate
    FROM
        ttremains t
),
-- Расчет количества дней периода
UniqueDates AS (
    SELECT
        article,
        STORELOC,
        COUNT(DISTINCT remdate) AS UniqueDatesCount
    FROM
        ttremains
    GROUP BY
        article,
        STORELOC
),
-- Получение цены на конец периода
LatestPrice AS (
    SELECT
        p.ARTICLE,
        p.PRICE,
        p.DOCEXECTIME,
        ROW_NUMBER() OVER (PARTITION BY p.ARTICLE ORDER BY p.DOCEXECTIME DESC) AS rn
    FROM
        SMPriceHistory p
    WHERE
        p.DOCEXECTIME <= (SELECT MAX(remdate) FROM ttremains WHERE article = p.ARTICLE)
)
-- Запрос данных
SELECT
    s.SHORTNAME AS Название,
    r.article,
    r.STORELOC AS ID_МХ,
    r.Сумма_остатков_периода,
    r.Quantity_Max_Remdate AS Остаток_на_конец_периода,
    lp.PRICE AS Последняя_цена,
    SUM(CASE WHEN r.STORELOC = d.LOCATIONFROM THEN sp.QUANTITY ELSE 0 END) AS Сумма_расходов,
    SUM(CASE WHEN r.STORELOC = d.LOCATIONTO THEN sp.QUANTITY ELSE 0 END) AS Сумма_приходов,
    SUM(CASE WHEN r.STORELOC = d.LOCATIONFROM AND d.DOCTYPE = 'CS' THEN sp.QUANTITY ELSE 0 END) AS Сумма_продаж,
    ROUND(SUM(CASE WHEN r.STORELOC = d.LOCATIONFROM AND d.DOCTYPE = 'CS' THEN sp.QUANTITY ELSE 0 END) / ud.UniqueDatesCount,2) AS ССР,
    ROUND(r.Сумма_остатков_периода / ud.UniqueDatesCount,2) AS Средний_остаток,
    CASE
        WHEN SUM(CASE WHEN r.STORELOC = d.LOCATIONFROM AND d.DOCTYPE = 'CS' THEN sp.QUANTITY ELSE 0 END) = 0
        THEN NULL
        ELSE ROUND((r.Сумма_остатков_периода / ud.UniqueDatesCount) / (SUM(CASE WHEN r.STORELOC = d.LOCATIONFROM AND d.DOCTYPE = 'CS' THEN sp.QUANTITY ELSE 0 END) / ud.UniqueDatesCount),2)
    END AS Оборачиваемость,
    CASE
        WHEN SUM(CASE WHEN r.STORELOC = d.LOCATIONFROM AND d.DOCTYPE = 'CS' THEN sp.QUANTITY ELSE 0 END) = 0
        THEN NULL
        ELSE ROUND((r.Quantity_Max_Remdate) / (SUM(CASE WHEN r.STORELOC = d.LOCATIONFROM AND d.DOCTYPE = 'CS' THEN sp.QUANTITY ELSE 0 END) / ud.UniqueDatesCount),2)
    END AS Запас_дн,
    sc.NORMTREE,
    sc.NAME
FROM
    Remains r
JOIN
    UniqueDates ud ON r.article = ud.article AND r.STORELOC = ud.STORELOC
JOIN
    smcard s ON r.article = s.article
JOIN
    smspec sp ON r.article = sp.article
JOIN
    SMDOCUMENTS d ON sp.DOCID = d.ID
JOIN
    SACARDCLASS sc ON s.IDCLASS = sc.ID
LEFT JOIN
    (SELECT ARTICLE, PRICE FROM LatestPrice WHERE rn = 1) lp ON r.article = lp.ARTICLE
WHERE
    d.CREATEDAT = r.remdate
    --AND r.STORELOC = 2  -- Отобрать только одно МХ
GROUP BY
    r.article,
    r.STORELOC,
    s.SHORTNAME,
    r.Сумма_остатков_периода,
    ud.UniqueDatesCount,
    r.Quantity_Max_Remdate,
    lp.PRICE,
    sc.NORMTREE,
    sc.NAME
ORDER BY
    ID_МХ, NORMTREE, ОБОРАЧИВАЕМОСТЬ;