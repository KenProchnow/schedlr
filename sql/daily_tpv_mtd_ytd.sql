declare @start as date , @end as date , @now as date, @startMTD as date , @startYTD as date,
@lyStart_MTD as date ,@lyStart_YTD as date ,@lyEnd_MTD as date , @lyEnd_YTD as date ;
 
set @now       = getdate()                          -- Today
set @end       = dateadd(d,-1,@now)  -- Yesterday
set @start     = dateadd(d,0,@end)           -- Yesterday minus one
set @startMTD  = dateadd(m, datediff(m, 0, @end), 0)
set @startYTD  = dateadd(yy, datediff(yy, 0, @end), 0)
 
set @lyEnd_MTD = '2015-01-01'
set @lyEnd_YTD = '2015-01-01'
set @lyStart_MTD = '2015-01-01'
set @lyStart_YTD = '2015-01-01'
 
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
 
select
    cast(txn.PostDate_R as date) as Date , c.Vertical,        
    sum(txn.amount * fx.Rate) as 'Yesterday', count(*) as Txn_Count
from                     
    YapstoneDM.dbo.[Transaction] txn with (nolock)                       
    inner join ETLStaging..FinanceParentTable c with (nolock) on c.PlatformId = txn.PlatformId and c.ChildCompanyId = txn.Ref_CompanyId  
       inner join YapstoneDM.dbo.Currency                                on txn.CurrencyId = Currency.CurrencyId
    inner join #Rates fx on  txn.PostDate_R = fx.Date and txn.CurrencyId = fx.CurrencyId 
where    1 = 1                
               and txn.PostDate_R between @start and @end           
               and txn.ProcessorId not in (14,16)                   
               and txn.TransactionCycleId in (1) 
               and txn.PlatformId in (1,2,3,4) -- No HA-Intl for now       
group by
       cast(txn.PostDate_R as date), c.Vertical