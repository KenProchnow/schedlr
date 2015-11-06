-- // Analytics Data tab for Analytics Dashboard
declare
---- Query Helpers
@paymentTypes as nvarchar(max),@Verticals as nvarchar(max),
---- Queries
@TPV_PaymentType as nvarchar(max), 
@TPV_Vertical as nvarchar(max)
;
select @paymentTypes = stuff((select ',' + quotename(colName) from (
   select distinct(PaymentTypeGroup) as colName 
   from ETLStaging..FinanceAnalytics
   union all
   select 'GatewayOnly' as colName
       ) sub order by colName for xml path(''), type).value('.', 'nvarchar(max)'),1,1,'')
select @Verticals = stuff((select ',' + quotename(colName) from (
	select distinct(Vertical) as colName 
	from ETLStaging..FinanceAnalytics
	union all
	select 'GatewayOnly' as colName
       ) sub order by colName for xml path(''), type).value('.', 'nvarchar(max)'),1,1,'')
set @TPV_PaymentType = '
with TPV as (
select *  from ( select Year, Month, cast(dateadd(d, -1 , dateadd(mm, (Year - 1900) * 12 + Month , 0)) as date) Date,  
       PaymentTypeGroup, sum(TPV_USD) TPV_USD
from   ETLStaging..FinanceAnalytics
where  Gateway in (''YapProcessing'')
group by Year, Month,  cast(dateadd(d, -1 , dateadd(mm, (Year - 1900) * 12 + Month , 0)) as date), 
      PaymentTypeGroup
union all
select Year, Month, cast(dateadd(d, -1 , dateadd(mm, (Year - 1900) * 12 + Month , 0)) as date) Date,  
       ''GatewayOnly'' as PaymentTypeGroup, sum(TPV_USD) TPV_USD
from   ETLStaging..FinanceAnalytics
where  Gateway in (''GatewayOnly'')
group by Year, Month,  cast(dateadd(d, -1 , dateadd(mm, (Year - 1900) * 12 + Month , 0)) as date)
      ) sub
pivot ( 
	sum(sub.TPV_USD)
    for [PaymentTypeGroup] in ('+@paymentTypes+') 
) as PivotTable )
select Date , '+@paymentTypes+'
from TPV;' 
set @TPV_Vertical = '
with TPV as (
select *  from (
select Year, Month,  cast(dateadd(d, -1 , dateadd(mm, (Year - 1900) * 12 + Month , 0)) as date) Date,  
       Vertical,   sum(TPV_USD) TPV_USD
from   ETLStaging..FinanceAnalytics
where  Gateway in (''YapProcessing'')
group by  Year, Month, cast(dateadd(d, -1 , dateadd(mm, (Year - 1900) * 12 + Month , 0)) as date), 
      Vertical
union all
select	Year, Month, cast(dateadd(d, -1 , dateadd(mm, (Year - 1900) * 12 + Month , 0)) as date) Date,
	''GatewayOnly'' as Vertical, sum(TPV_USD)
from
	ETLStaging..FinanceAnalytics
where
	Gateway in (''GatewayOnly'')
group by Year, Month, cast(dateadd(d, -1 , dateadd(mm, (Year - 1900) * 12 + Month , 0)) as date)
	 ) sub
pivot (
	sum(sub.TPV_USD)
    for [Vertical] in ('+@Verticals+')
) as PivotTable )
select Date , '+@Verticals+'
from TPV' 
exec sp_executesql @TPV_PaymentType
exec sp_executesql @TPV_Vertical
