var 
	parse = require('./../parse.js').parseSQL,
	query = require('./../query.js').executeQuery,
	email = require('./../email.js').email,
	html = true, // send results as html?
	file = 'daily_tpv'
	;

parse(file, function(sql){
	query(sql, file, function(result){
		email(file);
	});
});

