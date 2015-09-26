var 
	parse = require('./readFile.js').parseSQL,
	query = require('./executeQuery.js').executeQuery,
	file = 'daily_tpv'
	;

parse(file, function(sql){
	query(sql,file);
});

