/* This is the brainchild of the application */

// By Running npm run dev or yarn dev you will
/*
* Start The Dev Server
* Compile all KofuScript Files to the Lib Folder
* Compile the lib folder to a bundle
* Compile all SCSS to CSS
* Set up automatic file watchers for hot reload
*/

/* The Lib Folder Step is only in place so that you can see the JS Files that
 are generated from KofuScript in order to allow us the ability to see if our
  KofuScript input gave us the desired output....
*/
// Explanation for Students ---- This is requires the gulp package from node modules
// Gulp exports an object with many methods
// task , watch, src and pipe will be the main ones we use today but see the gulp docs to expand and also see how you might refactor it to no longer use task and maybe use exports, series and parallells
// i don't use them here because they are more magic and make it harder to show what's happening
const gulp = require('gulp');

// Explanation for Students ---- This is for compiling SASS, we haven't learned SASS yet but this is as good a chance as any to to talk about how we could compile it.
const sass = require('gulp-sass');

// Explanation for Students ---- This is for those pesky experimental features of css that are not available in all browsers without prefixes like webkit and moz
const autoprefixer = require('gulp-autoprefixer');

// Explanation for Students ---- This is the mastermind that will open up our code in a browser window
const browserSync = require('browser-sync').create();

// Explanation for Students ---- This is a browserSync method that reloads the page we wangt whenever we make a change to have the page reload
const reload = browserSync.reload;

// Explanation for Students ---- This is a NODEJS standard method that lets us call scripts in our package.json or node_modules from our code
var exec = require('child_process').exec;

const kofu = require('./gulp-kofu')


// Explanation for Students ---- This is the brain child for our self made development server

gulp.task('default', (cb) => {
	exec('npm run main', function(err, stdout, stderr) {
		console.log(stdout);
		console.log(stderr);
		browserSync.init({
			server: './public',
			notify: true,
			open: true //change this to true if you want the broser to open automatically
		});
		cb(err);
	});
	gulp.watch('./src/scss/**/*',  gulp.task('styles'));
	gulp.watch('./lib/components/**/*', gulp.task('webpack'));
	gulp.watch('./src/components/App.kofu', gulp.task('app'));
	gulp.watch('./src/components/collections/*', gulp.task('collections'));
	gulp.watch('./src/components/models/*', gulp.task('models'));
	gulp.watch('./src/components/views/*', gulp.task('views'));
	gulp
		.watch([
			'./public/**/*',
			'./public/*',
			'public/js/**/.#*js',
			'public/css/**/.#*css'
		])
		.on('change', reload);
		cb()
});

/*Models */
gulp.task('models', (cb)=> {
	gulp
		.src('src/components/models/**/*.kofu')
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
		.pipe(gulp.dest('./lib/components/models'))
		.pipe(browserSync.stream());
		cb();
})
/*Collections */
gulp.task('collections', (cb)=> {
	gulp
		.src('src/components/collections/**/*.kofu')
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
		.pipe(gulp.dest('./lib/components/collections'))
		.pipe(browserSync.stream());
		cb();
})
/* Views */
gulp.task('views', (cb)=> {
	gulp
		.src('src/components/views/**/*.kofu')
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
		.pipe(gulp.dest('./lib/components/views'))
		.pipe(browserSync.stream());
		cb();
})
/*App*/
gulp.task('app', (cb)=> {
	gulp
		.src('src/components/App.kofu')
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
		.pipe(gulp.dest('./lib/components'))
		.pipe(browserSync.stream());
		cb();
})

// Styles ---- This is compiles our SCSS Files
gulp.task('styles', (cb) => {
	gulp
		.src('src/scss/**/*.scss')
		.pipe(
			sass({
				outputStyle: 'compressed'
			}).on('error', sass.logError)
		)
		.pipe(
			autoprefixer({
				browsers: ['last 2 versions']
			})
		)
		.pipe(gulp.dest('./public/css'))
		.pipe(browserSync.stream());
		cb()
});

// Webpack ---- This is for the development build
gulp.task('webpack', cb => {
	exec('npm run dev:webpack', function(err, stdout, stderr) {
		console.log(stdout);
		console.log(stderr);
		cb(err);
	});
});

// Build ---- This is for the production build
gulp.task('build', cb => {
	exec('npm run build:webpack', function(err, stdout, stderr) {
		console.log(stdout);
		console.log(stderr);
		cb(err);
	});
});
// This is for the startup sequence
exports.main = gulp.series('collections', 'models', 'views', 'app', 'webpack');
