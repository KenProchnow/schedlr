var 
	parse = require('./readFile.js').parseSQL,
	query = require('./executeQuery.js').executeQuery,
	email = require('./lib/emailHTML.js').email,
	html = true, // send results as html?
	file = 'daily_tpv'
	;

parse(file, function(sql){
	query(sql, file, function(result){
		email(file);
	});
});

