const gulp = require ('gulp');
const mamba = require ('./gulp-mamba')
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
		.src('examples/**/*.mamba')
		.pipe(
			mamba({
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
		.src('smooth-mambascript/src/**/*.mamba')
		.pipe(
			mamba({
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
		.pipe(gulp.dest('./smooth-mambascript/src/compiled'));
		cb();
})
