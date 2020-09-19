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
	exec('npm run build', (err, stdout, stderr) => {
			consola.warn(err)
			consola.info(stdout)
			consola.info(stderr)
			cb(err)
	})
	cb();
})

gulp.task('example', (cb)=> {
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
		.pipe(gulp.dest('./examples/compiled'));
		cb();
})

gulp.task('smooth', (cb)=> {
	gulp
		.src('smooth-kofuscript/src/**/*.kofu')
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
		.pipe(gulp.dest('./smooth-kofuscript/src/compiled'));
		cb();
})
