const gulp = require ('gulp');
const kofu = require ('./gulp-kofu')
const exec = require('child-process').exec
const consola = require('consola')

gulp.task('default', (cb)=> {
	exec('npm run build', (err, stdout, stderr) => {
			consola.warn(err)
			consola.info(stdout)
			consola.info(stderr)
			cb(err)
	})
	gulp.watch('./src/**/*', gulp.task('compile'));
	cb();
})

gulp.task('compile', (cb)=> {
	gulp
		.src('src/**/*.kofu')
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
		.pipe(gulp.dest('./lib'));
})

gulp.task('examples', (cb)=> {
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
