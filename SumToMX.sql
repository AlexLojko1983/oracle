


select
    article,
    salelocationto,
    sum(QUANTITY) AS SaleQty
from FVMAPREP
where salelocationto= 2
    and saledate >= to_date('2024-07-20','yyyy-MM-dd')
group by article, salelocationto

