declare @start as date , @end as date , @now as date, @startMTD as date , @startYTD as date,
@lyStart_MTD as date ,@lyStart_YTD as date ,@lyEnd_MTD as date , @lyEnd_YTD as date , @dates as nvarchar(max) , @query as nvarchar(max);
 
set @now       = getdate()    -- Today
set @end       = dateadd(d,-2,@now)  -- Yesterday
set @start     = dateadd(d,0,@end)  -- Yesterday minus one
set @startMTD  = dateadd(m, datediff(m, 0, @end), 0)
set @startYTD  = dateadd(yy, datediff(yy, 0, @end), 0)
 
set @lyStart_MTD = dateadd(yy,-1,@startMTD)
set @lyEnd_MTD = dateadd(yy,-1, @end)
set @lyStart_YTD = dateadd(yy,-1,@startYTD)
set @lyEnd_YTD = dateadd(yy,-1, @end)
 
if object_id('tempdb..#EURUSD') is not null                drop table #EURUSD
select fx.Date, fx.ExchangeRate                                           into #EURUSD                 
from YapstoneDM..CurrencyExchangeRate fx
where  BaseCurrencyId in (1) and fx.CounterCurrencyId in (3)
     and (   fx.Date between @startYTD and @end or
             fx.Date between @lyStart_YTD and @lyEnd_YTD )
group by fx.Date, fx.ExchangeRate
 
if object_id('tempdb..#Rates') is not null                 drop table #Rates
select * into #Rates from (
     select fx.Date, Currency.CharCode, Currency.CurrencyId, 1 / ( fx.ExchangeRate / usd.ExchangeRate ) Rate
             
     from YapstoneDM..CurrencyExchangeRate fx  join YapstoneDM..Currency on fx.CounterCurrencyId = Currency.CurrencyId
                left join #EURUSD usd on fx.Date = usd.Date
     where
             (   fx.Date between @startYTD and @end or
             fx.Date between @lyStart_YTD and @lyEnd_YTD )
     group by fx.Date, Currency.CharCode, Currency.CurrencyId, 1 / ( fx.ExchangeRate / usd.ExchangeRate )
     union
     select fx.Date, Currency.CharCode, Currency.CurrencyId, fx.ExchangeRate                      
     from YapstoneDM..CurrencyExchangeRate fx  join YapstoneDM..Currency on fx.BaseCurrencyId = Currency.CurrencyId
     where  BaseCurrencyId in (1) and fx.CounterCurrencyId in (3)  
             and  (   fx.Date between @startYTD and @end or
             fx.Date between @lyStart_YTD and @lyEnd_YTD )
     group by fx.Date, Currency.CharCode, Currency.CurrencyId, fx.ExchangeRate
) src
 
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
       select distinct(Date) as colName from #txn
   ) sub_query order by colName for xml path(''), type).value('.', 'nvarchar(max)'),1,1,'')
 
 ---- Today, MTD, YTD, MTD%, YTD%
 
set @query = '
select Vertical,'+quotename(@end)+', 
  MTD, cast(cast(round((MTD/lyMTD -1)*100,2) as decimal(18,2)) as varchar)+''%'' as [MTD YoY],  
  YTD, cast(cast(round((YTD/lyYTD -1)*100,2) as decimal(18,2)) as varchar)+''%'' as [YTD YoY]
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

exec(@query)


