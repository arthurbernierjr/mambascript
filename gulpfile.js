const gulp = require ('gulp');
const kofu = require ('./gulp-kofu')


gulp.task('default', (cb)=> {
	gulp
		.src('examples/**/*.kofu')
		.pipe(
			kofu({
				jsAst: {
					bare: true,
					header: true
				},
				csAst: {
					bare: true
				},
				js: {
				header: true
				}
			}).on('error', (e)=>{
				console.log(e)
			})
		)
		.pipe(gulp.dest('./examples'));
		cb();
})
