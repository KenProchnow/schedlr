declare @start as date, @end as date  ;
 
set @start           = '2015-08-01'
set @end             = '2015-08-31'
 
select
       cast(dateadd(d, -1 , dateadd(mm, (year(txn.PostDate_R) - 1900) * 12 + month(txn.PostDate_R), 0)) as date) as Date ,
    c.Vertical,  c.ParentAccountId, c.ParentName , 
    CardBin.bin [IIN/Bin Number], CardBin.CardType, Cardbin.bank Issuer, isnull(Person.FirstName,'')+' '+isnull(Person.LastName,'') Person ,                     
    sum(txn.amount) Txn_Amount, sum(txn.AmtNetConvFee) ConvFee, count(*) as Txn_Count
from                      
    YapstoneDM.dbo.[Transaction] txn with (nolock)                        
    inner join ETLStaging..FinanceParentTable c with (nolock) on c.PlatformId = txn.PlatformId and c.ChildCompanyId = txn.Ref_CompanyId   
       join rpReportsTemp.rp.Transfer t on t.id = left(txn.IdClassId, charindex(':', txn.IdClassId) -1) and t.classId = right(txn.IdClassId, (len(txn.idclassid) - charindex(':', txn.IdClassId)))
       join rpReportsTemp.rp.CardBin on left(t.uiAccountNumber,6) = CardBin.bin and CardBin.source = 'Bin_DB'
      join YapstoneDM..Person on Person.PlatformId = txn.PlatformId and Person.PersonId = txn.Ref_PersonId
where    1 = 1                 
       and txn.PostDate_R between @start and @end            
       and txn.ProcessorId not in (14,16)                    
       and txn.TransactionCycleId in (1)              
       and txn.PlatformId in (1)               
       and c.Vertical in ('Rent')
       and (
 
( c.ParentName in ('CAF Capital Partners  LLC') and txn.Amount = 1030.95) or
( c.ParentName in ('Your Local Leasing Company') and txn.Amount = 1018.95) or
( c.ParentName in ('Timberland Partners Management Co') and txn.Amount = 910.95) or
( c.ParentName in ('Next Chapter Properties') and txn.Amount = 856.95) or
( c.ParentName in ('Quest Management Group') and txn.Amount = 799.95) or
( c.ParentName in ('IMS Management LLC') and txn.Amount = 777.45) or
( c.ParentName in ('Ramshaw Real Estate') and txn.Amount = 718.95) or
( c.ParentName in ('JC Spence Company') and txn.Amount = 520) or
( c.ParentName in ('B A  Feller Company') and txn.Amount = 365.91) or
( c.ParentName in ('Community Association Management') and txn.Amount = 227.95) or
( c.ParentName in ('Premium Solutions Group') and txn.Amount = 49.95)
 
)
       --and txn.AmtNetConvFee <> 0
       and txn.PaymentTypeId in (1)
group by      
       cast(dateadd(d, -1 , dateadd(mm, (year(txn.PostDate_R) - 1900) * 12 + month(txn.PostDate_R), 0)) as date),
       c.Vertical,  c.ParentAccountId, c.ParentName ,
       CardBin.bin,CardBin.CardType, Cardbin.bank , isnull(Person.FirstName,'')+' '+isnull(Person.LastName,'')
order by Txn_Count desc
 
 