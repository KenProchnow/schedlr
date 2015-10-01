# schedlr

## What

Tired of refreshing date variables of prior queries you've written? Want to schedule automatic jobs, with the results emailed to distrobution lists you can manage? Want it all scheduled with [`cron`](https://en.wikipedia.org/wiki/Cron)?

Need the results emailed to users, with the results in the `<html>` & `<table>` format?

## Install

`git clone git@github.com:skilbjo/schedlr`

### Raw `sql` Queries

Place this raw `sql` query into the `sql/` directory,

`daily_tpv.sql`:

````
declare @start as date , @end as date , @now as date;

set @now	= getdate()						-- Today
set @end	= dateadd(d,-1,@now)	-- Yesterday
set @start	= dateadd(d,0,@end)	-- Yesterday minus one

select
    cast(txn.PostDate_R as date) as Date , c.Vertical,         
    sum(txn.amount) Txn_Amount, count(*) as Txn_Count
from                      
    YapstoneDM.dbo.[Transaction] txn with (nolock)                        
    inner join ETLStaging..FinanceParentTable c with (nolock) on c.PlatformId = txn.PlatformId and c.ChildCompanyId = txn.Ref_CompanyId   
where    1 = 1                 
		and txn.PostDate_R between @start and @end            
		and txn.ProcessorId not in (14,16)                    
		and txn.TransactionCycleId in (1)        
group by
	cast(txn.PostDate_R as date), c.Vertical
````

### Create a job!

In the `jobs/` directory, create your mini-script, `daily_tpv.js`:

````
var 
	parse = require('./../parse.js').parseSQL,
	query = require('./../query.js').executeQuery,
	email = require('./../email.js').email,
	file = 'daily_tpv'
	;

parse(file, function(sql){
	query(sql, file, function(result){
		email(file);
	});
});
````

### Create the email distribution list

In the `lib/emailDistributionList/distributionList.js` file, create this object:

````
module.exports = {
	daily_tpv: [ 'john.skilbeck@hello-kitty.com' , 'john.skilbeck@github.com'  ]
};
````

### Schedule the job via `cron`

`$ crontab -e`

````
* 12 * * * * node jobs/daily_tpv.js 
````

Cron format is, [which] `minute(0-59) hour(0-23) [day of month(1 - 31)] month(1-12) [day of week(0-6)]`




