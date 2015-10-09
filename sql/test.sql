select top 50 *
from ETLStaging..FinanceTopData
where vertical not in ('Dues')
and year > 2014