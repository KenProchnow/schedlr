declare @start as date , @end as date , @now as date, @startMTD as date , @startYTD as date,
@lyStart_MTD as date ,@lyStart_YTD as date ,@lyEnd_MTD as date , @lyEnd_YTD as date , 
@dates as nvarchar(max) , @query as nvarchar(max) , @total as nvarchar(max) , @combined as nvarchar(max)  ;
 
set @now       = getdate()    -- Today
set @end       = dateadd(d,-1,@now)  -- Yesterday
set @start     = dateadd(d,0,@end)  -- Yesterday minus one
set @startMTD  = dateadd(m, datediff(m, 0, @end), 0)
set @startYTD  = dateadd(yy, datediff(yy, 0, @end), 0)
 
set @lyStart_MTD = dateadd(yy,-1,@startMTD)
set @lyEnd_MTD = dateadd(yy,-1, @end)
set @lyStart_YTD = dateadd(yy,-1,@startYTD)
set @lyEnd_YTD = dateadd(yy,-1, @end)
 
 

if object_id('tempdb..#CurrencyCodes') is not null drop table #CurrencyCodes
select Currency.CharCode, Currency.CurrencyId into #CurrencyCodes
from YapstoneDM..Currency
group by Currency.CharCode, Currency.CurrencyId
  
if object_id('tempdb..#Dates') is not null drop table #Dates
select * into #Dates from (
       select txn.postDate_R Date, c.CharCode, c.CurrencyId 
       from   YapstoneDM..[Transaction] txn
       cross join (
               select Currency.CharCode, Currency.CurrencyId
               from YapstoneDM..Currency
               group by Currency.CharCode, Currency.CurrencyId
       ) c
       where  txn.PostDate_R between @lyStart_YTD and @end
       group by txn.PostDate_R , c.CharCode, c.CurrencyId
) src
 
-- FX Rates
if object_id('tempdb..#EURUSD') is not null                drop table #EURUSD
select fx.Date, fx.ExchangeRate                                           into #EURUSD                
from YapstoneDM..CurrencyExchangeRate fx
where  BaseCurrencyId in (1) and fx.CounterCurrencyId in (3)
     and (   fx.Date between @lyStart_YTD and @end  )
group by fx.Date, fx.ExchangeRate
if object_id('tempdb..#RatesPREPROCESSED') is not null                 drop table #RatesPREPROCESSED
select * into #RatesPREPROCESSED from (
     select isnull(fx.Date,d.Date) Date, isnull(Currency.CharCode,d.CharCode) CharCode, isnull(Currency.CurrencyId,d.CurrencyId) CurrencyId,
                      1 / ( fx.ExchangeRate / usd.ExchangeRate ) Rate
     from #Dates d left join YapstoneDM..CurrencyExchangeRate fx  on d.Date = fx.Date
               left join YapstoneDM..Currency on fx.CounterCurrencyId = Currency.CurrencyId
               left join #EURUSD usd on fx.Date = usd.Date
     where  (   d.Date between @lyStart_YTD and @end )
     group by  isnull(fx.Date,d.Date) , isnull(Currency.CharCode,d.CharCode) , isnull(Currency.CurrencyId,d.CurrencyId)
                      , 1 / ( fx.ExchangeRate / usd.ExchangeRate )
     union
       select isnull(fx.Date,d.Date) Date, d.CharCode, d.CurrencyId ,fx.ExchangeRate                     
       from   #Dates d left join YapstoneDM..CurrencyExchangeRate fx  on d.Date = fx.Date and d.CurrencyId = fx.BaseCurrencyId
               and BaseCurrencyId in (1) and fx.CounterCurrencyId in (3)
               left join YapstoneDM..Currency on fx.CounterCurrencyId = Currency.CurrencyId
       where  d.CurrencyId in (1)
               and  (   d.Date between @lyStart_YTD and @end  )
       group by isnull(fx.Date,d.Date) , d.CharCode, d.CurrencyId, fx.ExchangeRate
) src
order by Date asc
 
 
if object_id('tempdb..#FallbackRates') is not null drop table #FallBackRates
select * into #FallbackRates from (
       select 'EUR' CharCode, 1.35 as Rate union select 'GBP', 1.6 union select 'CAD', 0.9 union select 'USD', 1
) src
 
if object_id('tempdb..#Rates') is not null                 drop table #Rates
select Date,src.CharCode,CurrencyId,isnull(src.Rate,fallback.Rate) Rate  into #Rates from (
       select Date,CharCode,CurrencyId,(
               select top 1 Rate
               from   #RatesPREPROCESSED r1
               where  r1.Date <= r.Date
                              and r1.Rate is not null
                              and r1.CharCode = r.CharCode
               order by r1.Date desc
       ) Rate
       from #RatesPREPROCESSED r
) src left join #FallBackRates fallback on fallback.CharCode = src.CharCode
 
if object_id('tempdb..#Yesterday') is not null drop table #Yesterday
select
     case when txn.PostDate_R between @start and @end then cast(@end as varchar)
     end as Date ,
    c.Vertical,        
    sum(txn.amount * fx.Rate) as TPV
    into #Yesterday
from                     
    YapstoneDM.dbo.[Transaction] txn with (nolock)                       
    inner join ETLStaging..FinanceParentTable c with (nolock) on c.PlatformId = txn.PlatformId and c.ChildCompanyId = txn.Ref_CompanyId  
    inner join YapstoneDM.dbo.Currency                                on txn.CurrencyId = Currency.CurrencyId
    inner join #Rates fx on  txn.PostDate_R = fx.Date and txn.CurrencyId = fx.CurrencyId 
where    1 = 1                
     and ( txn.PostDate_R between @start and @end
     )     
     and txn.ProcessorId not in (14,16)                   
     and txn.TransactionCycleId in (1) 
     and ( case when txn.paymenttypeid in (1, 2, 3, 11, 12, /* <-- regular cards */ /* pre 2012 debit networks --> */  6,7,8,9) then 1
			when txn.PaymentTypeId in (10) and txn.ProcessorId in (22) and txn.Ref_BatchTypeId in (1) /* Amex , Bucket , Vantiv = Processing */ then 1
		else 0 end
     ) = 1
     and txn.PlatformId in (1,2,3,4) -- No HA-Intl for now       
group by
     case when txn.PostDate_R between @start and @end then cast(@end as varchar)
     end , c.Vertical
      
      
if object_id('tempdb..#MTD') is not null drop table #MTD
select
     case when txn.PostDate_R between @startMTD and @end then 'MTD'
             when txn.PostDate_R between @lyStart_MTD and @lyEnd_MTD then 'lyMTD'
     end as Date ,
    c.Vertical,        
    sum(txn.amount * fx.Rate) as TPV
    into #MTD
from                     
    YapstoneDM.dbo.[Transaction] txn with (nolock)                       
    inner join ETLStaging..FinanceParentTable c with (nolock) on c.PlatformId = txn.PlatformId and c.ChildCompanyId = txn.Ref_CompanyId  
     inner join YapstoneDM.dbo.Currency                                on txn.CurrencyId = Currency.CurrencyId
    inner join #Rates fx on  txn.PostDate_R = fx.Date and txn.CurrencyId = fx.CurrencyId 
where    1 = 1                
     and ( txn.PostDate_R between @startMTD and @end or
             txn.PostDate_R between @lyStart_MTD and @lyEnd_MTD
     )     
     and txn.ProcessorId not in (14,16)                   
     and txn.TransactionCycleId in (1) 
     and ( case when txn.paymenttypeid in (1, 2, 3, 11, 12, /* <-- regular cards */ /* pre 2012 debit networks --> */  6,7,8,9) then 1
			when txn.PaymentTypeId in (10) and txn.ProcessorId in (22) and txn.Ref_BatchTypeId in (1) /* Amex , Bucket , Vantiv = Processing */ then 1
		else 0 end
     ) = 1
     and txn.PlatformId in (1,2,3,4) -- No HA-Intl for now       
group by
     case when txn.PostDate_R between @startMTD and @end then 'MTD'
             when txn.PostDate_R between @lyStart_MTD and @lyEnd_MTD then 'lyMTD'
     end , c.Vertical
      
if object_id('tempdb..#YTD') is not null drop table #YTD
select
     case when txn.PostDate_R between @startYTD and @end then 'YTD'
             when txn.PostDate_R between @lyStart_YTD and @lyEnd_YTD then 'lyYTD'
     end as Date ,
    c.Vertical,        
    sum(txn.amount * fx.Rate) as TPV
    into #YTD
from                     
    YapstoneDM.dbo.[Transaction] txn with (nolock)                       
    inner join ETLStaging..FinanceParentTable c with (nolock) on c.PlatformId = txn.PlatformId and c.ChildCompanyId = txn.Ref_CompanyId  
     inner join YapstoneDM.dbo.Currency                                on txn.CurrencyId = Currency.CurrencyId
    inner join #Rates fx on  txn.PostDate_R = fx.Date and txn.CurrencyId = fx.CurrencyId 
where    1 = 1                
     and ( txn.PostDate_R between @startYTD and @end or
             txn.PostDate_R between @lyStart_YTD and @lyEnd_YTD
     )     
     and txn.ProcessorId not in (14,16)                   
     and txn.TransactionCycleId in (1) 
     and ( case when txn.paymenttypeid in (1, 2, 3, 11, 12, /* <-- regular cards */ /* pre 2012 debit networks --> */  6,7,8,9) then 1
			when txn.PaymentTypeId in (10) and txn.ProcessorId in (22) and txn.Ref_BatchTypeId in (1) /* Amex , Bucket , Vantiv = Processing */ then 1
		else 0 end
     ) = 1
     and txn.PlatformId in (1,2,3,4) -- No HA-Intl for now       
group by
     case when txn.PostDate_R between @startYTD and @end then 'YTD'
             when txn.PostDate_R between @lyStart_YTD and @lyEnd_YTD then 'lyYTD'
     end , c.Vertical
 
if object_id('tempdb..#txn') is not null drop table #txn
select * into #txn from (
       select * from #Yesterday union
       select * from #MTD union
       select * from #YTD
) src 
 
set @dates = stuff((select ',' + quotename(convert(varchar(10),colName)) from (
       select distinct(Date) as colName from #txn union select cast(@end as varchar)
   ) sub_query order by colName for xml path(''), type).value('.', 'nvarchar(max)'),1,1,'')
 
 
 
 ---- Today, MTD, YTD, MTD%, YTD%
 
set @query = '
select Vertical, '+quotename(@end)+' as '+quotename(@end)+',  
  MTD, cast(cast(round((MTD/lyMTD -1)*100,2) as decimal(18,2)) as varchar)+''%'' as [MTD YoY],  
  YTD, cast(cast(round((YTD/lyYTD -1)*100,2) as decimal(18,2)) as varchar)+''%'' as [YTD YoY]
  into #Vertical
from (
select * from (
select
       Date, Vertical, TPV
from
       #txn txn
) src
pivot (
       sum(TPV)
       for Date in ('+@dates+')
) pt
) src'

set @total = '
select ''Total'' as Vertical, '+quotename(@end)+' as '+quotename(@end)+',  
  MTD, cast(cast(round((MTD/lyMTD -1)*100,2) as decimal(18,2)) as varchar)+''%'' as [MTD YoY],  
  YTD, cast(cast(round((YTD/lyYTD -1)*100,2) as decimal(18,2)) as varchar)+''%'' as [YTD YoY]
  into #Total
from (
select * from (
select
       Date, TPV
from
       #txn txn
) src
pivot (
       sum(TPV)
       for Date in ('+@dates+')
) pt
) src'

set @combined = '
select * from #Vertical union all select * from #Total
'

exec(@query+';'+@total+';'+@combined)

